/* debris_event.c — 运动/PIR/GPIO 事件上报（ioctl + poll EPOLLPRI） */
#include <linux/kernel.h>
#include "debris.h"

void debris_motion_init(struct debris_dev_data *dev)
{
    init_waitqueue_head(&dev->motion_wq);
    dev->motion_count = 0;
    dev->motion_last_ts = 0;
    dev->motion_last_src = 0;
    dev->motion_pending = false;
}

void debris_motion_report(struct debris_dev_data *dev, u32 source, u64 ts_ns)
{
    unsigned long flags;

    if (!dev)
        return;

    spin_lock_irqsave(&dev->slock, flags);
    dev->motion_count++;
    dev->motion_last_ts = ts_ns;
    dev->motion_last_src = source;
    dev->motion_pending = true;
    spin_unlock_irqrestore(&dev->slock, flags);

    wake_up_interruptible(&dev->motion_wq);
}

void debris_motion_get(struct debris_dev_data *dev, struct debris_motion_event *ev)
{
    unsigned long flags;

    spin_lock_irqsave(&dev->slock, flags);
    ev->timestamp_ns = dev->motion_last_ts;
    ev->count = (u32)dev->motion_count;
    ev->source = dev->motion_last_src;
    dev->motion_pending = false;
    spin_unlock_irqrestore(&dev->slock, flags);
}

void debris_motion_clear(struct debris_dev_data *dev)
{
    unsigned long flags;

    spin_lock_irqsave(&dev->slock, flags);
    dev->motion_count = 0;
    dev->motion_last_ts = 0;
    dev->motion_last_src = 0;
    dev->motion_pending = false;
    spin_unlock_irqrestore(&dev->slock, flags);
}

bool debris_motion_poll(struct debris_dev_data *dev)
{
    unsigned long flags;
    bool pending;

    spin_lock_irqsave(&dev->slock, flags);
    pending = dev->motion_pending;
    spin_unlock_irqrestore(&dev->slock, flags);
    return pending;
}
