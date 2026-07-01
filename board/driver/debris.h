/* debris.h — 项目公共头文件 */
#ifndef _DEBRIS_H
#define _DEBRIS_H

#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/io.h>
#include <linux/types.h>
#include <linux/spinlock.h>
#include <linux/wait.h>
#include <linux/hrtimer.h>
#include <linux/interrupt.h>
#include <linux/slab.h>
#include <linux/string.h>
#include "debris_ring.h"

/* 用户态共享（uapi）；与 include/debris_uapi.h 保持一致 */
struct debris_motion_event {
    u64 timestamp_ns;
    u32 count;
    u32 source;
};

#define DEBRIS_MOTION_SRC_NONE 0
#define DEBRIS_MOTION_SRC_GPIO 1

/* ─── ioctl 命令 ─────────────────────────────────────────────── */
#define DEBRIS_MAGIC       'D'
#define DEBRIS_CLEAR       _IO(DEBRIS_MAGIC, 0)
#define DEBRIS_GETSIZE     _IOR(DEBRIS_MAGIC, 1, int)
#define DEBRIS_TIMER_STOP  _IO(DEBRIS_MAGIC, 2)
#define DEBRIS_TIMER_START _IO(DEBRIS_MAGIC, 3)
#define DEBRIS_GET_MOTION   _IOR(DEBRIS_MAGIC, 4, struct debris_motion_event)
#define DEBRIS_CLEAR_MOTION _IO(DEBRIS_MAGIC, 5)

/* Phase 3: platform / device-tree 侧信息（probe 时填充，remove 时释放）*/
struct debris_platform_info {
    char            label[32];
    phys_addr_t     mmio_phys;
    void __iomem   *mmio;
    unsigned int    ring_size;
    unsigned int    frame_size;
    int             gpio_btn;   /* from DT, -1 if unset */
    bool            dt_bound;
    int             i2c_adapter;   /* from DT, -1 if unset */
    int             sensor_addr;   /* 7-bit I2C addr, -1 if unset */
    unsigned int    camera_count;  /* number of cameras (1 or 2) */
    int             cam1_i2c_adapter;
    int             cam1_sensor_addr;
};

/* ─── 设备私有数据结构体 ──────────────────────────────────────── */
struct debris_dev_data {
    struct device          *dev;    /* platform 父设备，用于 devm 绑定 */

    /* 字符设备 */
    struct cdev             cdev;
    struct class           *cls;
    dev_t                   devno;

    /* 环形帧缓冲 */
    struct debris_ring      ring;
    spinlock_t              slock;    /* 保护 ring，供 softirq 使用 */

    /* 统计 */
    unsigned long           read_count;
    unsigned long           write_count;

    /* 等待队列 + 定时器 + tasklet */
    wait_queue_head_t       wq;
    wait_queue_head_t       motion_wq;
    struct hrtimer          timer;
    struct tasklet_struct   tasklet;

    /* GPIO / PIR 运动事件 */
    unsigned long           motion_count;
    u64                     motion_last_ts;
    u32                     motion_last_src;
    bool                    motion_pending;

    struct debris_platform_info *plat;
};

/* ─── 子模块接口 ──────────────────────────────────────────────── */
struct debris_dev_data *debris_get_data(void);

int  debris_proc_init(struct debris_dev_data *dev);
void debris_proc_exit(struct debris_dev_data *dev);

int  debris_irq_init(struct debris_dev_data *dev);
void debris_irq_exit(struct debris_dev_data *dev);

int  debris_gpio_init(struct debris_dev_data *dev);
void debris_gpio_exit(struct debris_dev_data *dev);

void debris_motion_init(struct debris_dev_data *dev);
void debris_motion_report(struct debris_dev_data *dev, u32 source, u64 ts_ns);
void debris_motion_get(struct debris_dev_data *dev, struct debris_motion_event *ev);
void debris_motion_clear(struct debris_dev_data *dev);
bool debris_motion_poll(struct debris_dev_data *dev);

void debris_get_module_params(unsigned int *ring_sz, unsigned int *frame_sz);
int  debris_device_register(struct device *parent, struct debris_platform_info *plat);
void debris_device_unregister(void);

int  debris_platform_register(void);
void debris_platform_unregister(void);

int debris_i2c_init(struct debris_dev_data *dev);
void debris_i2c_exit(struct debris_dev_data *dev);
void debris_i2c_get_status(bool *ok, u16 *chip_id, int *adap_nr, int *addr,
                           bool *reset_ok, u8 *sw_standby);
void debris_i2c_get_sensor_mode(bool *init_ok, u16 *width, u16 *height);
void debris_i2c_get_cam1_status(bool *ok, u16 *chip_id, int *adap_nr, int *addr);
#endif /* _DEBRIS_H */
