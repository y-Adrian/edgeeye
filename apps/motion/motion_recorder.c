/* motion_recorder.c — 运动触发 H.264 本地录像（RTSP copy 模式）
 *
 * 测试接口：poll(DEBRIS EPOLLPRI) + ffmpeg -c copy
 * 测试场景：正常路径（运动事件触发 clip）；边界（冷却期内忽略）；异常（无 ffmpeg 时跳过）
 *
 * 用法：
 *   ./motion_recorder [clip_sec] [cooldown_sec]
 * 环境变量：
 *   CLIP_DIR      录像目录（默认 /mnt/sd/clips，回退 /mnt/data/clips）
 *   RTSP_URL      主路 RTSP（默认 rtsp://127.0.0.1:8554/cam0）
 *   RTSP_URL2     双摄第二路（默认 rtsp://127.0.0.1:8554/cam1，空则跳过）
 *   FFMPEG        ffmpeg 路径（默认 ffmpeg）
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

static volatile sig_atomic_t g_stop;

static void on_sig(int sig)
{
    (void)sig;
    g_stop = 1;
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
    /* mkdir：创建 clip 目录（含父目录需已存在） */
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
             "-i '%s' -c copy -t %d '%s' &",
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

static int run_dry_run(const char *dir)
{
    int fd;

    printf("motion_recorder dry-run\n");
    printf("  clip_dir=%s\n", dir);

    if (ensure_dir(dir) != 0) {
        fprintf(stderr, "dry-run: cannot create %s: %s\n", dir, strerror(errno));
        return 1;
    }
    printf("  clip_dir ok\n");

    fd = open(DEV_PATH, O_RDONLY | O_NONBLOCK);
    if (fd < 0) {
        fprintf(stderr, "dry-run: open %s: %s (ok if ko not loaded)\n",
                DEV_PATH, strerror(errno));
        return 0;
    }
    close(fd);
    printf("  %s ok\n", DEV_PATH);
    return 0;
}

int main(int argc, char **argv)
{
    const char *dir, *ffmpeg, *url1, *url2;
    int clip_sec = 30;
    int cooldown_sec = 15;
    int fd, epfd, nfds, recording = 0;
    time_t last_clip = 0;
    struct epoll_event ev_ep, events[1];
    struct debris_motion_event ev;

    if (argc >= 2 && strcmp(argv[1], "--help") == 0) {
        printf("usage: %s [--dry-run] [clip_sec] [cooldown_sec]\n", argv[0]);
        return 0;
    }
    if (argc >= 2 && strcmp(argv[1], "--dry-run") == 0) {
        dir = getenv("CLIP_DIR");
        if (!dir)
            dir = clip_dir_default();
        return run_dry_run(dir);
    }

    if (argc >= 2)
        clip_sec = atoi(argv[1]);
    if (argc >= 3)
        cooldown_sec = atoi(argv[2]);
    if (clip_sec < 5)
        clip_sec = 5;
    if (cooldown_sec < 5)
        cooldown_sec = 5;

    dir = getenv("CLIP_DIR");
    if (!dir)
        dir = clip_dir_default();
    ffmpeg = resolve_ffmpeg(getenv("FFMPEG"));
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
        fprintf(stderr, "motion_recorder: ffmpeg not found, recording disabled\n");
        fprintf(stderr, "  set FFMPEG=/mnt/data/bin/ffmpeg or record from PC via RTSP\n");
        return 1;
    }

    /* open：打开 debris 字符设备，供 poll/ioctl 读取运动事件 */
    fd = open(DEV_PATH, O_RDONLY | O_NONBLOCK);
    if (fd < 0) {
        fprintf(stderr, "motion_recorder: open %s: %s\n",
                DEV_PATH, strerror(errno));
        return 1;
    }

    epfd = epoll_create1(0);
    if (epfd < 0) {
        perror("epoll_create1");
        close(fd);
        return 1;
    }

    ev_ep.events = EPOLLPRI;
    ev_ep.data.fd = fd;
    /* epoll_ctl：注册 EPOLLPRI 监听 GPIO/驱动运动事件 */
    if (epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev_ep) < 0) {
        perror("epoll_ctl");
        close(epfd);
        close(fd);
        return 1;
    }

    printf("motion_recorder: dir=%s clip=%ds cooldown=%ds url=%s\n",
           dir, clip_sec, cooldown_sec, url1);
    if (url2 && url2[0])
        printf("motion_recorder: dual url2=%s\n", url2);

    while (!g_stop) {
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
            memset(&ev, 0, sizeof(ev));
            /* ioctl：读取运动计数与时间戳 */
            if (ioctl(fd, DEBRIS_GET_MOTION, &ev) < 0) {
                perror("DEBRIS_GET_MOTION");
                continue;
            }
            if (ev.count == 0)
                continue;

            time_t now = time(NULL);
            if (recording || (now - last_clip) < cooldown_sec) {
                printf("motion_recorder: skip count=%u (cooldown)\n", ev.count);
                continue;
            }

            recording = 1;
            last_clip = now;
            trigger_record(ffmpeg, dir, clip_sec, url1, url2);
            recording = 0;
        }
    }

    close(epfd);
    close(fd);
    printf("motion_recorder: exit\n");
    return 0;
}
