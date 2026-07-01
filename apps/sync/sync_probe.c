/* sync_probe.c — 双目软时间戳对齐探测（Phase 6 sync 预留）
 *
 * 测试接口：/proc/debris + RTSP URL 可达性
 * 测试场景：单摄/双摄模式下打印对齐提示，不做硬件帧同步
 *
 * 用法：./sync_probe [dual]
 */
#define _POSIX_C_SOURCE 199309L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static void read_proc_field(const char *key, char *buf, size_t len)
{
    FILE *f;

    buf[0] = '\0';
    f = fopen("/proc/debris", "r");
    if (!f)
        return;

    while (fgets(buf, len, f)) {
        if (strncmp(buf, key, strlen(key)) == 0)
            break;
        buf[0] = '\0';
    }
    fclose(f);

    len = strlen(buf);
    if (len > 0 && buf[len - 1] == '\n')
        buf[len - 1] = '\0';
}

int main(int argc, char **argv)
{
    int dual = 0;
    char line[256];
    struct timespec ts;

    if (argc >= 2 && strcmp(argv[1], "dual") == 0)
        dual = 1;

    /* clock_gettime：读取单调时钟作为软对齐参考 */
    clock_gettime(CLOCK_MONOTONIC, &ts);

    printf("sync_probe: monotonic=%lld.%09ld ns\n",
           (long long)ts.tv_sec, ts.tv_nsec);

    read_proc_field("camera_count_dt", line, sizeof(line));
    if (line[0])
        printf("  %s\n", line);

    read_proc_field("cam1_i2c_ok", line, sizeof(line));
    if (line[0])
        printf("  %s\n", line);

    if (dual) {
        printf("sync_probe: dual mode — soft timestamp pairing only\n");
        printf("  cam0 rtsp://127.0.0.1:8554/cam0\n");
        printf("  cam1 rtsp://127.0.0.1:8554/cam1\n");
        printf("  strict stereo sync needs HW trigger (future)\n");
    } else {
        printf("sync_probe: single camera soft sync baseline\n");
    }

    return 0;
}
