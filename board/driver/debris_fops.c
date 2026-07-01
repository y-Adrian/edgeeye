/* debris_fops.c — file_operations 实现（Phase 5：ring buffer）
 *
 * 锁层次：
 *   slock（spinlock）— 保护 ring，hrtimer/tasklet/fops 共用
 *   read 路径在 slock 外调用 copy_to_user / wait_event_interruptible
 *   write 路径在 slock 外调用 copy_from_user
 */
#include <linux/kernel.h>
#include <linux/uaccess.h>
#include <linux/string.h>
#include <linux/poll.h>
#include "debris.h"
#include "debris_fops.h"

/* ─── open ────────────────────────────────────────────────────── */
static int debris_open(struct inode *inode, struct file *file)
{
    /* private_data 存 dev 指针，供其他 fops 回调使用 */
    file->private_data = debris_get_data();
    pr_debug("debris: open\n");
    return 0;
}

/* ─── release ─────────────────────────────────────────────────── */
static int debris_release(struct inode *inode, struct file *file)
{
    pr_debug("debris: release\n");
    return 0;
}

/* ─── llseek ──────────────────────────────────────────────────── */
/* ring buffer 语义下不支持 seek，返回错误 */
static loff_t debris_llseek(struct file *file, loff_t offset, int whence)
{
    return -ESPIPE;
}

/* ─── read ────────────────────────────────────────────────────── */
/*
 * 每次 read 消费 ring tail 处的一整帧。
 * 若 ring 为空则阻塞，直到生产者写入新帧。
 */
static ssize_t debris_read(struct file *file, char __user *ubuf,
                           size_t count, loff_t *ppos)
{
    struct debris_dev_data *dev = file->private_data;
    char *kbuf;
    size_t len;
    int n, ret;

    /* kmalloc：分配一帧大小的内核临时缓冲，用于在锁外拷贝到用户态 */
    kbuf = kmalloc(dev->ring.frame_sz, GFP_KERNEL);
    if (!kbuf)
        return -ENOMEM;

    /* 等待 ring 非空（在 slock 外睡眠）*/
    ret = wait_event_interruptible(dev->wq, !ring_empty(&dev->ring));
    if (ret == -ERESTARTSYS) {
        kfree(kbuf);
        return -ERESTARTSYS;
    }

    /* spin_lock：从 ring tail 取出一帧（ring_pop 内部已判空）*/
    spin_lock_bh(&dev->slock);
    n = ring_pop(&dev->ring, kbuf, dev->ring.frame_sz);
    if (n < 0) {
        /* 惊群唤醒后 ring 被其他 reader 抢空，返回 0 */
        spin_unlock_bh(&dev->slock);
        kfree(kbuf);
        return 0;
    }
    dev->read_count++;
    spin_unlock_bh(&dev->slock);

    /* copy_to_user：在锁外将数据拷贝到用户态 */
    len = min(count, (size_t)n);
    if (copy_to_user(ubuf, kbuf, len)) {
        kfree(kbuf);
        return -EFAULT;
    }

    kfree(kbuf);
    return (ssize_t)len;
}

/* ─── write ───────────────────────────────────────────────────── */
static ssize_t debris_write(struct file *file, const char __user *ubuf,
                            size_t count, loff_t *ppos)
{
    struct debris_dev_data *dev = file->private_data;
    char *kbuf;
    size_t len = min(count, (size_t)dev->ring.frame_sz);

    /* 0 字节写入：不入队空帧，直接返回，避免污染 ring 并误唤醒 reader */
    if (len == 0)
        return 0;

    /* kmalloc：分配一帧大小的内核临时缓冲 */
    kbuf = kmalloc(dev->ring.frame_sz, GFP_KERNEL);
    if (!kbuf)
        return -ENOMEM;

    /* copy_from_user：在锁外从用户态拷贝，避免持锁睡眠 */
    if (copy_from_user(kbuf, ubuf, len)) {
        kfree(kbuf);
        return -EFAULT;
    }

    spin_lock_bh(&dev->slock);
    ring_push(&dev->ring, kbuf, len);
    dev->write_count++;
    spin_unlock_bh(&dev->slock);

    kfree(kbuf);

    /* wake_up_interruptible：通知等待读的进程有新帧 */
    wake_up_interruptible(&dev->wq);
    return (ssize_t)len;
}

/* ─── ioctl ───────────────────────────────────────────────────── */
static long debris_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
    struct debris_dev_data *dev = file->private_data;
    int ret = 0;
    int frame_size = dev->ring.frame_sz;

    switch (cmd) {
    case DEBRIS_CLEAR:
        /* spin_lock_bh：清空 ring，仅重置 head/tail（不可 memset 整个 ring，
         * 否则会清掉 frames 指针与 size/frame_sz 等运行时字段）*/
        spin_lock_bh(&dev->slock);
        dev->ring.head = 0;
        dev->ring.tail = 0;
        spin_unlock_bh(&dev->slock);
        pr_debug("debris: ioctl CLEAR\n");
        break;

    case DEBRIS_GETSIZE:
        /* copy_to_user：把每帧最大字节数返回给用户 */
        if (copy_to_user((int __user *)arg, &frame_size, sizeof(int)))
            ret = -EFAULT;
        break;

    case DEBRIS_TIMER_STOP:
        /* hrtimer_cancel：停止周期定时器 */
        hrtimer_cancel(&dev->timer);
        break;

    case DEBRIS_TIMER_START:
        /* hrtimer_start：启动定时器，33ms 后第一次触发 */
        hrtimer_start(&dev->timer, ms_to_ktime(33), HRTIMER_MODE_REL);
        break;

    case DEBRIS_GET_MOTION: {
        struct debris_motion_event ev;

        /* debris_motion_get：读取运动事件计数与时间戳，并清除 pending */
        debris_motion_get(dev, &ev);
        if (copy_to_user((void __user *)arg, &ev, sizeof(ev)))
            ret = -EFAULT;
        break;
    }

    case DEBRIS_CLEAR_MOTION:
        debris_motion_clear(dev);
        break;

    default:
        ret = -EINVAL;
    }
    return ret;
}

/* ─── poll ────────────────────────────────────────────────────── */
static __poll_t debris_poll(struct file *file, poll_table *wait)
{
    struct debris_dev_data *dev = file->private_data;
    __poll_t mask = 0;

    /* poll_wait：把进程挂入等待队列，不阻塞，让内核决定何时再调 poll */
    poll_wait(file, &dev->wq, wait);
    poll_wait(file, &dev->motion_wq, wait);

    spin_lock_bh(&dev->slock);
    if (!ring_empty(&dev->ring))
        mask |= EPOLLIN | EPOLLRDNORM;
    if (dev->motion_pending)
        mask |= EPOLLPRI;
    spin_unlock_bh(&dev->slock);

    return mask;
}

/* ─── fops 表 ─────────────────────────────────────────────────── */
const struct file_operations debris_fops = {
    .owner          = THIS_MODULE,
    .open           = debris_open,
    .release        = debris_release,
    .llseek         = debris_llseek,
    .read           = debris_read,
    .write          = debris_write,
    .unlocked_ioctl = debris_ioctl,
    .poll           = debris_poll,
};
