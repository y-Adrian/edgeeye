/* motion_detect_v4l2.c — 基于 V4L2 的真实帧运动检测（vendor /dev/video0）
 *
 * 测试接口：/dev/video0 VIDIOC_* + mmap
 * 测试场景：vendor pipeline 可用时对连续帧做差分；否则打印提示并退出
 *
 * 用法：./motion_detect_v4l2 [device] [threshold] [frames]
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <poll.h>
#include <linux/videodev2.h>

#ifndef V4L2_PIX_FMT_YUYV
#define V4L2_PIX_FMT_YUYV v4l2_fourcc('Y', 'U', 'Y', 'V')
#endif

static int frame_diff_yuyv(const unsigned char *a, const unsigned char *b, int len)
{
    int i, sum = 0;

    for (i = 0; i + 1 < len; i += 2) {
        int d = (int)a[i] - (int)b[i];

        if (d < 0)
            d = -d;
        sum += d;
    }
    return sum;
}

int main(int argc, char *argv[])
{
    const char *devpath = "/dev/video0";
    int threshold = 5000;
    int max_frames = 30;
    int fd, ret, i, motion_hits = 0;
    struct v4l2_capability cap;
    struct v4l2_format fmt;
    struct v4l2_requestbuffers req;
    struct v4l2_buffer buf;
    enum v4l2_buf_type type;
    unsigned char *map = MAP_FAILED;
    unsigned char *prev = NULL;
    size_t map_len = 0;

    if (argc > 1)
        devpath = argv[1];
    if (argc > 2)
        threshold = atoi(argv[2]);
    if (argc > 3)
        max_frames = atoi(argv[3]);

    fd = open(devpath, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "motion_detect_v4l2: open %s: %s\n",
                devpath, strerror(errno));
        fprintf(stderr, "Hint: start vendor VI pipeline first (see docs/MVP_MEDIA_PIPELINE.md)\n");
        return 2;
    }

    if (ioctl(fd, VIDIOC_QUERYCAP, &cap) < 0) {
        perror("VIDIOC_QUERYCAP");
        close(fd);
        return 1;
    }
    printf("device: %s (%s)\n", cap.card, devpath);

    memset(&fmt, 0, sizeof(fmt));
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width = 640;
    fmt.fmt.pix.height = 480;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
    fmt.fmt.pix.field = V4L2_FIELD_NONE;
    if (ioctl(fd, VIDIOC_S_FMT, &fmt) < 0) {
        perror("VIDIOC_S_FMT");
        close(fd);
        return 1;
    }
    map_len = fmt.fmt.pix.sizeimage;

    memset(&req, 0, sizeof(req));
    req.count = 1;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    if (ioctl(fd, VIDIOC_REQBUFS, &req) < 0 || req.count < 1) {
        perror("VIDIOC_REQBUFS");
        close(fd);
        return 1;
    }

    memset(&buf, 0, sizeof(buf));
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    buf.index = 0;
    if (ioctl(fd, VIDIOC_QUERYBUF, &buf) < 0) {
        perror("VIDIOC_QUERYBUF");
        close(fd);
        return 1;
    }

    map = mmap(NULL, buf.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, buf.m.offset);
    if (map == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return 1;
    }
    map_len = buf.length;

    if (ioctl(fd, VIDIOC_QBUF, &buf) < 0) {
        perror("VIDIOC_QBUF");
        munmap(map, map_len);
        close(fd);
        return 1;
    }

    type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if (ioctl(fd, VIDIOC_STREAMON, &type) < 0) {
        perror("VIDIOC_STREAMON");
        munmap(map, map_len);
        close(fd);
        return 1;
    }

    prev = malloc(map_len);
    if (!prev) {
        fprintf(stderr, "malloc failed\n");
        goto out_streamoff;
    }

    for (i = 0; i < max_frames; i++) {
        struct pollfd pfd = { .fd = fd, .events = POLLIN };

        if (poll(&pfd, 1, 3000) <= 0) {
            fprintf(stderr, "poll timeout frame %d\n", i);
            break;
        }

        if (ioctl(fd, VIDIOC_DQBUF, &buf) < 0) {
            perror("VIDIOC_DQBUF");
            break;
        }

        if (i > 0) {
            int diff = frame_diff_yuyv(prev, map, (int)buf.bytesused);

            printf("v4l2 frame %d diff=%d%s\n", i, diff,
                   diff >= threshold ? "  MOTION" : "");
            if (diff >= threshold)
                motion_hits++;
        }
        memcpy(prev, map, buf.bytesused);

        if (ioctl(fd, VIDIOC_QBUF, &buf) < 0) {
            perror("VIDIOC_QBUF");
            break;
        }
    }

    printf("motion_detect_v4l2: %d/%d frames over threshold %d\n",
           motion_hits, max_frames - 1, threshold);

out_streamoff:
    type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    ioctl(fd, VIDIOC_STREAMOFF, &type);
    if (map != MAP_FAILED)
        munmap(map, map_len);
    free(prev);
    close(fd);
    return 0;
}
