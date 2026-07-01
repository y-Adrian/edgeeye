/* debris_uapi.h — 用户态与 debris.ko 共享的 ioctl 定义 */
#ifndef _DEBRIS_UAPI_H
#define _DEBRIS_UAPI_H

#include <sys/ioctl.h>
#include <linux/types.h>

#define DEBRIS_MAGIC       'D'
#define DEBRIS_CLEAR       _IO(DEBRIS_MAGIC, 0)
#define DEBRIS_GETSIZE     _IOR(DEBRIS_MAGIC, 1, int)
#define DEBRIS_TIMER_STOP  _IO(DEBRIS_MAGIC, 2)
#define DEBRIS_TIMER_START _IO(DEBRIS_MAGIC, 3)

#define DEBRIS_MOTION_SRC_NONE 0
#define DEBRIS_MOTION_SRC_GPIO 1

struct debris_motion_event {
	__u64 timestamp_ns;
	__u32 count;
	__u32 source;
};

#define DEBRIS_GET_MOTION   _IOR(DEBRIS_MAGIC, 4, struct debris_motion_event)
#define DEBRIS_CLEAR_MOTION _IO(DEBRIS_MAGIC, 5)

#endif /* _DEBRIS_UAPI_H */
