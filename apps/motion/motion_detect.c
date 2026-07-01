/* motion_detect.c — Phase 6 运动检测原型（基于 debris 虚拟帧）
 *
 * 测试接口：/dev/debris_kernel read + poll + ioctl
 * 测试场景：连续读取 hrtimer 注入帧，帧差超过阈值则报告 MOTION
 *
 * 用法：
 *   ./motion_detect [threshold] [frames]
 *   threshold — 字节差累加阈值（默认 64）
 *   frames    — 采样帧数（默认 30）
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <errno.h>
#include "debris_uapi.h"

#define DEV_PATH "/dev/debris_kernel"

static int frame_diff(const unsigned char *a, const unsigned char *b, int len)
{
    int i, sum = 0;

    for (i = 0; i < len; i++) {
        int d = (int)a[i] - (int)b[i];

        if (d < 0)
            d = -d;
        sum += d;
    }
    return sum;
}

int main(int argc, char *argv[])
{
    int threshold = 64;
    int max_frames = 30;
    int fd, frame_sz, ret, i, motion_hits = 0;
    unsigned char *prev = NULL;
    unsigned char *cur = NULL;
    struct pollfd pfd;

    if (argc > 1)
        threshold = atoi(argv[1]);
    if (argc > 2)
        max_frames = atoi(argv[2]);
    if (max_frames < 2)
        max_frames = 2;

    fd = open(DEV_PATH, O_RDWR);
    if (fd < 0) {
        perror("open " DEV_PATH);
        return 1;
    }

    if (ioctl(fd, DEBRIS_GETSIZE, &frame_sz) < 0 || frame_sz <= 0) {
        perror("ioctl DEBRIS_GETSIZE");
        close(fd);
        return 1;
    }

    prev = malloc(frame_sz);
    cur = malloc(frame_sz);
    if (!prev || !cur) {
        fprintf(stderr, "malloc failed\n");
        free(prev);
        free(cur);
        close(fd);
        return 1;
    }

    ioctl(fd, DEBRIS_TIMER_STOP, 0);
    ioctl(fd, DEBRIS_CLEAR, 0);
    ioctl(fd, DEBRIS_TIMER_START, 0);

    pfd.fd = fd;
    pfd.events = POLLIN;

    for (i = 0; i < max_frames; i++) {
        ret = poll(&pfd, 1, 3000);
        if (ret <= 0) {
            fprintf(stderr, "poll timeout/error at frame %d\n", i);
            break;
        }

        ret = read(fd, cur, frame_sz);
        if (ret <= 0) {
            perror("read");
            break;
        }

        if (i > 0) {
            int diff = frame_diff(prev, cur, ret);

            printf("frame %d diff=%d%s\n", i, diff,
                   diff >= threshold ? "  MOTION" : "");
            if (diff >= threshold)
                motion_hits++;
        }

        memcpy(prev, cur, ret);
    }

    ioctl(fd, DEBRIS_TIMER_STOP, 0);
    free(prev);
    free(cur);
    close(fd);

    printf("motion_detect: %d/%d frames over threshold %d\n",
           motion_hits, max_frames - 1, threshold);
    return 0;
}
