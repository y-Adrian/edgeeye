/* motion_recorder.c — 运动触发 H.264 本地录像（RTSP copy 模式）
 *
 * 测试接口：RTSP 帧差分 或 poll(DEBRIS EPOLLPRI) + ffmpeg -c copy
 * 测试场景：软件动检触发 clip；GPIO/PIR 触发；冷却期内忽略；无 ffmpeg 时退出
 *
 * 用法：
 *   ./motion_recorder [clip_sec] [cooldown_sec]
 * 环境变量：
 *   MOTION_SOURCE   rtsp | debris | auto（默认 rtsp）
 *   MOTION_THRESHOLD  JPEG 字节差分阈值（默认 3000，仅 rtsp/auto）
 *   MOTION_INTERVAL_SEC  探测间隔秒（默认 2）
 *   CLIP_DIR        录像目录（默认 /mnt/sd/clips，回退 /mnt/data/clips）
 *   RTSP_URL        主路 RTSP（默认 rtsp://127.0.0.1:8554/cam0）
 *   RTSP_URL2       双摄第二路（默认同上 cam1，空则跳过）
 *   FFMPEG          ffmpeg 路径
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <sys/epoll.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include "debris_uapi.h"

#define DEV_PATH "/dev/debris_kernel"
#define PROBE_W 160
#define PROBE_H 120
#define PROBE_JPEG_MAX 65536
#define PROBE_TIMEOUT_SEC 90

typedef struct {
    unsigned char buf[PROBE_JPEG_MAX];
    size_t        len;
    int           have;
} probe_state_t;

static volatile sig_atomic_t g_stop;

enum motion_src_mode {
    MOTION_SRC_RTSP = 0,
    MOTION_SRC_DEBRIS,
    MOTION_SRC_AUTO,
};

static void on_sig(int sig)
{
    (void)sig;
    g_stop = 1;
}

static void reap_children(void)
{
    int st;

    /* waitpid：非阻塞回收 ffmpeg 录像子进程，避免僵尸进程 */
    while (waitpid(-1, &st, WNOHANG) > 0)
        ;
}

static const char *clip_dir_default(void)
{
    if (access("/mnt/sd", W_OK) == 0)
        return "/mnt/sd/clips";
    return "/mnt/data/clips";
}

static int ensure_dir(const char *path)
{
    struct stat st;

    if (stat(path, &st) == 0) {
        if (S_ISDIR(st.st_mode))
            return 0;
        return -1;
    }
    /* mkdir：创建 clip 目录 */
    if (mkdir(path, 0755) == 0)
        return 0;
    if (errno == EEXIST)
        return 0;
    return -1;
}

static int ffmpeg_exists(const char *bin)
{
    static const char *fallbacks[] = {
        "ffmpeg",
        "/usr/bin/ffmpeg",
        "/mnt/system/usr/bin/ffmpeg",
        "/mnt/data/bin/ffmpeg",
        NULL,
    };
    int i;

    if (bin && access(bin, X_OK) == 0)
        return 1;

    for (i = 0; fallbacks[i]; i++) {
        if (access(fallbacks[i], X_OK) == 0)
            return 1;
    }
    return 0;
}

static const char *resolve_ffmpeg(const char *hint)
{
    static const char *paths[] = {
        "/mnt/data/bin/ffmpeg",
        "/mnt/system/usr/bin/ffmpeg",
        "/usr/bin/ffmpeg",
        "ffmpeg",
        NULL,
    };
    int i;

    if (hint && hint[0] && access(hint, X_OK) == 0)
        return hint;
    for (i = 0; paths[i]; i++) {
        if (access(paths[i], X_OK) == 0)
            return paths[i];
    }
    return hint ? hint : "ffmpeg";
}

static enum motion_src_mode parse_motion_source(const char *s)
{
    if (!s || !s[0] || strcmp(s, "rtsp") == 0)
        return MOTION_SRC_RTSP;
    if (strcmp(s, "debris") == 0 || strcmp(s, "gpio") == 0)
        return MOTION_SRC_DEBRIS;
    if (strcmp(s, "auto") == 0)
        return MOTION_SRC_AUTO;
    fprintf(stderr, "motion_recorder: unknown MOTION_SOURCE=%s (use rtsp|debris|auto)\n", s);
    return MOTION_SRC_RTSP;
}

static void spawn_clip(const char *ffmpeg, const char *dir,
                       const char *url, const char *tag,
                       int clip_sec)
{
    char outpath[512];
    char cmd[1024];
    time_t now = time(NULL);
    pid_t pid;

    snprintf(outpath, sizeof(outpath), "%s/%ld_%s.mp4",
             dir, (long)now, tag);

    snprintf(cmd, sizeof(cmd),
             "%s -y -loglevel warning -rtsp_transport tcp "
             "-analyzeduration 1000000 -probesize 500000 "
             "-i '%s' -c copy -t %d '%s'",
             ffmpeg, url, clip_sec, outpath);

    printf("motion_recorder: clip %s\n", outpath);
    fflush(stdout);

    pid = fork();
    if (pid < 0) {
        perror("fork");
        return;
    }
    if (pid == 0) {
        execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
        _exit(127);
    }
}

static void trigger_record(const char *ffmpeg, const char *dir,
                           int clip_sec, const char *url1,
                           const char *url2)
{
    spawn_clip(ffmpeg, dir, url1, "cam0", clip_sec);
    if (url2 && url2[0])
        spawn_clip(ffmpeg, dir, url2, "cam1", clip_sec);
}

static int frame_diff_bytes(const unsigned char *a, const unsigned char *b, size_t n)
{
    size_t i;
    int sum = 0;

    for (i = 0; i < n; i++) {
        int d = (int)a[i] - (int)b[i];

        if (d < 0)
            d = -d;
        sum += d;
    }
    return sum;
}

static int run_cmd_sync(const char *cmd)
{
    int ret;

    /* system：同步执行 shell 命令 */
    ret = system(cmd);
    if (ret < 0)
        return -1;
    if (WIFEXITED(ret))
        return WEXITSTATUS(ret);
    return -1;
}

static int run_cmd_timeout(const char *cmd, int sec)
{
    char wrapped[2048];

    if (sec > 0 && access("/usr/bin/timeout", X_OK) == 0) {
        snprintf(wrapped, sizeof(wrapped),
                 "/usr/bin/timeout %d sh -c '%s'", sec, cmd);
        return run_cmd_sync(wrapped);
    }
    return run_cmd_sync(cmd);
}

static int read_file_into(const char *path, unsigned char *buf, size_t max,
                          size_t *out_len)
{
    int fd;
    ssize_t nread;

    fd = open(path, O_RDONLY);
    if (fd < 0)
        return -1;

    nread = read(fd, buf, max);
    close(fd);
    if (nread <= 0)
        return -1;

    *out_len = (size_t)nread;
    return 0;
}

static int grab_jpeg_probe(const char *ffmpeg, const char *url,
                           const char *outpath)
{
    char cmd[1024];
    struct stat st;

    snprintf(cmd, sizeof(cmd),
             "%s -y -loglevel error -rtsp_transport tcp "
             "-analyzeduration 2000000 -probesize 1000000 "
             "-i '%s' -vf scale=%d:%d -frames:v 1 -q:v 10 "
             "-f image2 '%s'",
             ffmpeg, url, PROBE_W, PROBE_H, outpath);

    if (run_cmd_timeout(cmd, PROBE_TIMEOUT_SEC) != 0)
        return -1;
    if (stat(outpath, &st) != 0 || st.st_size < 64)
        return -1;
    return 0;
}

static int motion_from_rtsp_probe(const char *ffmpeg, const char *url,
                                  const char *tag, int threshold,
                                  probe_state_t *st)
{
    char path[128];
    unsigned char cur[PROBE_JPEG_MAX];
    size_t cur_len = 0;
    size_t cmp_len;
    int diff;

    snprintf(path, sizeof(path), "/tmp/motion_%s.jpg", tag);

    if (grab_jpeg_probe(ffmpeg, url, path) != 0) {
        fprintf(stderr, "motion_recorder: probe failed tag=%s url=%s\n",
                tag, url);
        return 0;
    }

    if (read_file_into(path, cur, sizeof(cur), &cur_len) != 0) {
        fprintf(stderr, "motion_recorder: read probe %s failed\n", path);
        unlink(path);
        return 0;
    }
    unlink(path);

    if (!st->have) {
        if (cur_len > PROBE_JPEG_MAX)
            cur_len = PROBE_JPEG_MAX;
        memcpy(st->buf, cur, cur_len);
        st->len = cur_len;
        st->have = 1;
        printf("motion_recorder: probe baseline tag=%s bytes=%zu\n",
               tag, cur_len);
        fflush(stdout);
        return 0;
    }

    cmp_len = st->len < cur_len ? st->len : cur_len;
    diff = frame_diff_bytes(st->buf, cur, cmp_len);
    if (cur_len > PROBE_JPEG_MAX)
        cur_len = PROBE_JPEG_MAX;
    memcpy(st->buf, cur, cur_len);
    st->len = cur_len;

    printf("motion_recorder: probe diff=%d threshold=%d tag=%s bytes=%zu\n",
           diff, threshold, tag, cur_len);
    fflush(stdout);
    return diff >= threshold;
}

static int can_trigger_clip(time_t now, time_t last_clip, int cooldown_sec)
{
    if (last_clip == 0)
        return 1;
    return (now - last_clip) >= cooldown_sec;
}

static int run_dry_run(const char *dir, const char *ffmpeg)
{
    int fd;

    printf("motion_recorder dry-run\n");
    printf("  clip_dir=%s\n", dir);
    printf("  ffmpeg=%s\n", ffmpeg);

    if (ensure_dir(dir) != 0) {
        fprintf(stderr, "dry-run: cannot create %s: %s\n", dir, strerror(errno));
        return 1;
    }
    printf("  clip_dir ok\n");

    if (!ffmpeg_exists(ffmpeg)) {
        fprintf(stderr, "dry-run: ffmpeg not found\n");
        return 1;
    }
    printf("  ffmpeg ok\n");

    fd = open(DEV_PATH, O_RDONLY | O_NONBLOCK);
    if (fd < 0) {
        printf("  %s: not loaded (rtsp mode still ok)\n", DEV_PATH);
    } else {
        close(fd);
        printf("  %s ok\n", DEV_PATH);
    }
    return 0;
}

static int run_rtsp_loop(const char *ffmpeg, const char *dir,
                         const char *url1, const char *url2,
                         int clip_sec, int cooldown_sec,
                         int threshold, int interval_sec)
{
    probe_state_t st0;
    probe_state_t st1;
    time_t last_clip = 0;

    memset(&st0, 0, sizeof(st0));
    memset(&st1, 0, sizeof(st1));

    printf("motion_recorder: rtsp mode interval=%ds threshold=%d url=%s\n",
           interval_sec, threshold, url1);

    while (!g_stop) {
        int motion = 0;
        time_t now;

        reap_children();
        motion = motion_from_rtsp_probe(ffmpeg, url1, "cam0", threshold, &st0);
        if (!motion && url2 && url2[0])
            motion = motion_from_rtsp_probe(ffmpeg, url2, "cam1", threshold, &st1);

        if (motion) {
            now = time(NULL);
            if (can_trigger_clip(now, last_clip, cooldown_sec)) {
                last_clip = now;
                trigger_record(ffmpeg, dir, clip_sec, url1, url2);
            } else {
                printf("motion_recorder: skip (cooldown)\n");
            }
        }

        sleep(interval_sec > 0 ? interval_sec : 2);
    }

    return 0;
}

static int run_debris_loop(int fd, int epfd, const char *ffmpeg, const char *dir,
                           const char *url1, const char *url2,
                           int clip_sec, int cooldown_sec)
{
    time_t last_clip = 0;

    printf("motion_recorder: debris mode url=%s\n", url1);

    while (!g_stop) {
        struct epoll_event events[1];
        int nfds;

        reap_children();
        nfds = epoll_wait(epfd, events, 1, 1000);
        if (nfds < 0) {
            if (errno == EINTR)
                continue;
            perror("epoll_wait");
            break;
        }
        if (nfds == 0)
            continue;

        if (events[0].events & (EPOLLPRI | EPOLLERR | EPOLLHUP)) {
            struct debris_motion_event ev;

            memset(&ev, 0, sizeof(ev));
            /* ioctl：读取 GPIO/PIR 运动事件 */
            if (ioctl(fd, DEBRIS_GET_MOTION, &ev) < 0) {
                perror("DEBRIS_GET_MOTION");
                continue;
            }
            if (ev.count == 0)
                continue;

            {
                time_t now = time(NULL);

                if (!can_trigger_clip(now, last_clip, cooldown_sec)) {
                    printf("motion_recorder: skip count=%u (cooldown)\n", ev.count);
                    continue;
                }
                last_clip = now;
                printf("motion_recorder: debris motion count=%u src=%u\n",
                       ev.count, ev.source);
                trigger_record(ffmpeg, dir, clip_sec, url1, url2);
            }
        }
    }

    return 0;
}

static int run_auto_loop(int fd, int epfd, const char *ffmpeg, const char *dir,
                         const char *url1, const char *url2,
                         int clip_sec, int cooldown_sec,
                         int threshold, int interval_sec)
{
    probe_state_t st0;
    probe_state_t st1;
    time_t last_clip = 0;
    int wait_ms = interval_sec > 0 ? interval_sec * 1000 : 2000;

    memset(&st0, 0, sizeof(st0));
    memset(&st1, 0, sizeof(st1));

    printf("motion_recorder: auto mode (debris + rtsp fallback) interval=%ds\n",
           interval_sec);

    while (!g_stop) {
        struct epoll_event events[1];
        int nfds, motion = 0;
        time_t now;

        reap_children();
        nfds = epoll_wait(epfd, events, 1, wait_ms);
        if (nfds < 0) {
            if (errno == EINTR)
                continue;
            perror("epoll_wait");
            break;
        }

        if (nfds > 0 && (events[0].events & (EPOLLPRI | EPOLLERR | EPOLLHUP))) {
            struct debris_motion_event ev;

            memset(&ev, 0, sizeof(ev));
            if (ioctl(fd, DEBRIS_GET_MOTION, &ev) == 0 && ev.count > 0)
                motion = 1;
        }

        if (!motion) {
            motion = motion_from_rtsp_probe(ffmpeg, url1, "cam0", threshold, &st0);
            if (!motion && url2 && url2[0])
                motion = motion_from_rtsp_probe(ffmpeg, url2, "cam1", threshold, &st1);
        }

        if (motion) {
            now = time(NULL);
            if (can_trigger_clip(now, last_clip, cooldown_sec)) {
                last_clip = now;
                trigger_record(ffmpeg, dir, clip_sec, url1, url2);
            } else {
                printf("motion_recorder: skip (cooldown)\n");
            }
        }
    }

    return 0;
}

static int open_debris_epoll(int *fd_out, int *epfd_out)
{
    int fd, epfd;
    struct epoll_event ev_ep;

    fd = open(DEV_PATH, O_RDONLY | O_NONBLOCK);
    if (fd < 0)
        return -1;

    epfd = epoll_create1(0);
    if (epfd < 0) {
        close(fd);
        return -1;
    }

    ev_ep.events = EPOLLPRI;
    ev_ep.data.fd = fd;
    /* epoll_ctl：监听 debris 运动事件（EPOLLPRI） */
    if (epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev_ep) < 0) {
        close(epfd);
        close(fd);
        return -1;
    }

    *fd_out = fd;
    *epfd_out = epfd;
    return 0;
}

int main(int argc, char **argv)
{
    const char *dir, *ffmpeg, *url1, *url2, *src_env;
    enum motion_src_mode src_mode;
    int clip_sec = 30;
    int cooldown_sec = 15;
    int threshold = 3000;
    int interval_sec = 2;
    int fd = -1, epfd = -1;
    int ret = 0;

    if (argc >= 2 && strcmp(argv[1], "--help") == 0) {
        printf("usage: %s [--dry-run] [clip_sec] [cooldown_sec]\n", argv[0]);
        printf("env: MOTION_SOURCE=rtsp|debris|auto MOTION_THRESHOLD MOTION_INTERVAL_SEC\n");
        return 0;
    }

    dir = getenv("CLIP_DIR");
    if (!dir)
        dir = clip_dir_default();
    ffmpeg = resolve_ffmpeg(getenv("FFMPEG"));

    if (argc >= 2 && strcmp(argv[1], "--dry-run") == 0)
        return run_dry_run(dir, ffmpeg);

    if (argc >= 2)
        clip_sec = atoi(argv[1]);
    if (argc >= 3)
        cooldown_sec = atoi(argv[2]);
    if (clip_sec < 5)
        clip_sec = 5;
    if (cooldown_sec < 5)
        cooldown_sec = 5;

    src_env = getenv("MOTION_SOURCE");
    src_mode = parse_motion_source(src_env);

    if (getenv("MOTION_THRESHOLD"))
        threshold = atoi(getenv("MOTION_THRESHOLD"));
    if (getenv("MOTION_INTERVAL_SEC"))
        interval_sec = atoi(getenv("MOTION_INTERVAL_SEC"));
    if (threshold < 500)
        threshold = 500;
    if (interval_sec < 1)
        interval_sec = 1;

    url1 = getenv("RTSP_URL");
    if (!url1)
        url1 = "rtsp://127.0.0.1:8554/cam0";
    url2 = getenv("RTSP_URL2");
    if (!url2)
        url2 = "rtsp://127.0.0.1:8554/cam1";

    signal(SIGINT, on_sig);
    signal(SIGTERM, on_sig);

    if (ensure_dir(dir) != 0) {
        fprintf(stderr, "motion_recorder: mkdir %s: %s\n", dir, strerror(errno));
        return 1;
    }

    if (!ffmpeg_exists(ffmpeg)) {
        fprintf(stderr, "motion_recorder: ffmpeg not found\n");
        fprintf(stderr, "  set FFMPEG=/mnt/data/bin/ffmpeg or run build_ffmpeg_cli.sh\n");
        return 1;
    }

    printf("motion_recorder: dir=%s clip=%ds cooldown=%ds source=%s\n",
           dir, clip_sec, cooldown_sec,
           src_env && src_env[0] ? src_env : "rtsp");

    if (src_mode == MOTION_SRC_DEBRIS || src_mode == MOTION_SRC_AUTO) {
        if (open_debris_epoll(&fd, &epfd) < 0) {
            if (src_mode == MOTION_SRC_DEBRIS) {
                fprintf(stderr, "motion_recorder: open %s: %s\n",
                        DEV_PATH, strerror(errno));
                return 1;
            }
            fprintf(stderr, "motion_recorder: %s unavailable, rtsp-only fallback\n",
                    DEV_PATH);
            src_mode = MOTION_SRC_RTSP;
        }
    }

    switch (src_mode) {
    case MOTION_SRC_RTSP:
        ret = run_rtsp_loop(ffmpeg, dir, url1, url2, clip_sec, cooldown_sec,
                            threshold, interval_sec);
        break;
    case MOTION_SRC_DEBRIS:
        ret = run_debris_loop(fd, epfd, ffmpeg, dir, url1, url2,
                              clip_sec, cooldown_sec);
        break;
    case MOTION_SRC_AUTO:
        ret = run_auto_loop(fd, epfd, ffmpeg, dir, url1, url2,
                            clip_sec, cooldown_sec, threshold, interval_sec);
        break;
    default:
        ret = 1;
        break;
    }

    if (epfd >= 0)
        close(epfd);
    if (fd >= 0)
        close(fd);

    printf("motion_recorder: exit\n");
    return ret;
}
