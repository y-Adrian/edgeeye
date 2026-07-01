/* debris_irq.c — hrtimer（上半部）+ tasklet（下半部）
 *
 * 上半部（hrtimer）：记录时间戳，调度 tasklet，尽快返回
 * 下半部（tasklet）：构造虚拟帧，推入 ring buffer，唤醒 waitqueue
 */
#include <linux/kernel.h>
#include <linux/ktime.h>
#include "debris.h"

/* ─── tasklet 下半部 ──────────────────────────────────────────── */
static void debris_tasklet_fn(unsigned long data)
{
    struct debris_dev_data *dev = (struct debris_dev_data *)data;
    struct timespec64 ts;
    /* 时间戳字符串很短，用固定栈缓冲即可；ring_push 会按 frame_sz 截断，
     * 避免在 softirq 上下文做可能睡眠的内存分配 */
    char msg[64];
    size_t len;

    /* ktime_get_real_ts64：获取当前实时时间戳 */
    ktime_get_real_ts64(&ts);
    len = snprintf(msg, sizeof(msg), "frame @ %lld.%06ld\n",
                   ts.tv_sec, ts.tv_nsec / 1000);

    pr_debug("debris: [tasklet] processed @ %lld ns\n",
             ktime_to_ns(ktime_get()));

    /* spin_lock：把新帧推入 ring buffer */
    spin_lock(&dev->slock);
    ring_push(&dev->ring, msg, len);
    dev->write_count++;
    spin_unlock(&dev->slock);

    /* wake_up_interruptible：通知阻塞在 read/poll 的进程 */
    wake_up_interruptible(&dev->wq);
}

/* ─── hrtimer 上半部 ──────────────────────────────────────────── */
static enum hrtimer_restart debris_timer_callback(struct hrtimer *timer)
{
    struct debris_dev_data *dev =
        container_of(timer, struct debris_dev_data, timer);

    pr_debug("debris: [hrtimer]  fired    @ %lld ns\n",
             ktime_to_ns(ktime_get()));

    /* tasklet_schedule：调度下半部，立即返回 */
    tasklet_schedule(&dev->tasklet);

    /* hrtimer_forward_now：基于上次到期时间推进 33ms，避免误差累积 */
    hrtimer_forward_now(timer, ms_to_ktime(33));
    return HRTIMER_RESTART;
}

/* ─── init / exit ─────────────────────────────────────────────── */
int debris_irq_init(struct debris_dev_data *dev)
{
    /* tasklet_init：初始化 tasklet，绑定回调和 dev 指针 */
    tasklet_init(&dev->tasklet, debris_tasklet_fn, (unsigned long)dev);

    /* hrtimer_init：初始化高精度定时器，使用单调时钟，相对时间模式 */
    hrtimer_init(&dev->timer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
    dev->timer.function = debris_timer_callback;

    /* hrtimer_start：33ms 后触发第一次回调 */
    hrtimer_start(&dev->timer, ms_to_ktime(33), HRTIMER_MODE_REL);
    return 0;
}

void debris_irq_exit(struct debris_dev_data *dev)
{
    /* 先停 timer，再杀 tasklet，避免 timer 不断调度 tasklet 导致死锁 */
    hrtimer_cancel(&dev->timer);
    tasklet_kill(&dev->tasklet);
}
