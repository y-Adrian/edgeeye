/* debris_gpio.c — 真实 GPIO 硬中断（上半部）+ workqueue（下半部）
 *
 * 上半部（hardirq）：极短，软件去抖 + 记录时间戳 + 调度 workqueue，立即返回
 * 下半部（workqueue）：可睡眠上下文，构造事件帧推入 ring buffer，唤醒 waitqueue
 *
 * 用法：insmod debris.ko gpio_btn=<全局GPIO号>
 *   gpio_btn < 0（默认）时不启用 GPIO 中断，驱动其余功能照常工作。
 */
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/gpio.h>          /* gpio_request / gpio_to_irq / gpio_free 等 */
#include <linux/interrupt.h>     /* request_irq / free_irq / IRQF_* */
#include <linux/workqueue.h>     /* INIT_WORK / schedule_work / cancel_work_sync */
#include <linux/ktime.h>
#include <linux/jiffies.h>
#include "debris.h"

/* insmod 时传入按键/PIR 的全局 GPIO 号，-1 表示不启用 */
static int gpio_btn = -1;
module_param(gpio_btn, int, 0444);
MODULE_PARM_DESC(gpio_btn,
    "Global GPIO number for button/PIR (e.g. A20=500 on Duo S); -1 disables GPIO IRQ");

/* 去抖窗口（毫秒）：机械按键一次按下会有几十次边沿抖动 */
#define DEBRIS_GPIO_DEBOUNCE_MS 20

/* 模块内部状态：保存申请到的 irq 号与上半部记录的时间戳 */
static int           g_irq = -1;
static int           g_active_gpio = -1;  /* module_param or DT resolved */
static ktime_t       g_irq_ts;
static unsigned long g_last_jiffies;

static int debris_resolve_gpio_btn(struct debris_dev_data *dev)
{
    if (gpio_btn >= 0)
        return gpio_btn;
    if (dev && dev->plat && dev->plat->gpio_btn >= 0)
        return dev->plat->gpio_btn;
    return -1;
}

/* ─── 下半部：workqueue，可睡眠上下文 ─────────────────────────── */
static void debris_gpio_work_fn(struct work_struct *work)
{
    struct debris_dev_data *dev = debris_get_data();
    char   msg[64];
    size_t len;

    /* 构造一帧事件，携带上半部记录的硬中断时间戳 */
    len = snprintf(msg, sizeof(msg), "gpio irq @ %lld ns", ktime_to_ns(g_irq_ts));

    /* spin_lock_bh：复用现有 ring，与 tasklet/fops 共用 slock，
     * 工作队列运行在进程上下文，用 _bh 变体禁软中断以防与 tasklet 争锁 */
    spin_lock_bh(&dev->slock);
    ring_push(&dev->ring, msg, len);
    dev->write_count++;
    spin_unlock_bh(&dev->slock);

    /* wake_up_interruptible：唤醒阻塞在 read/poll 的进程 */
    wake_up_interruptible(&dev->wq);

    /* debris_motion_report：上报 PIR/GPIO 运动事件供 ioctl/poll 消费 */
    debris_motion_report(dev, DEBRIS_MOTION_SRC_GPIO, ktime_to_ns(g_irq_ts));
}
static DECLARE_WORK(debris_gpio_work, debris_gpio_work_fn);

/* ─── 上半部：硬中断上下文，必须极短，禁止睡眠 ──────────────────── */
static irqreturn_t debris_gpio_isr(int irq, void *dev_id)
{
    unsigned long now = jiffies;

    /* 软件去抖：去抖窗口内的抖动直接忽略 */
    if (time_before(now, g_last_jiffies + msecs_to_jiffies(DEBRIS_GPIO_DEBOUNCE_MS)))
        return IRQ_HANDLED;
    g_last_jiffies = now;

    /* ktime_get：记录中断发生时刻；schedule_work：调度下半部后立即返回 */
    g_irq_ts = ktime_get();
    schedule_work(&debris_gpio_work);
    return IRQ_HANDLED;
}

/* ─── init / exit ─────────────────────────────────────────────── */
int debris_gpio_init(struct debris_dev_data *dev)
{
    int ret;
    int btn;

    btn = debris_resolve_gpio_btn(dev);
    if (btn < 0) {
        pr_info("debris: gpio_btn not configured, skip GPIO interrupt\n");
        return 0;
    }

    /* gpio_request：向 gpiolib 申请该 GPIO 的所有权 */
    ret = gpio_request(btn, "debris_btn");
    if (ret) {
        pr_err("debris: gpio_request(%d) failed: %d\n", btn, ret);
        return ret;
    }

    /* gpio_direction_input：配置为输入，作为中断源 */
    ret = gpio_direction_input(btn);
    if (ret) {
        pr_err("debris: gpio_direction_input(%d) failed: %d\n", btn, ret);
        goto err_free_gpio;
    }

    /* gpio_to_irq：把 GPIO 号转换为可供 request_irq 使用的 IRQ 号 */
    g_irq = gpio_to_irq(btn);
    if (g_irq < 0) {
        pr_err("debris: gpio_to_irq(%d) failed: %d (pin may not support IRQ)\n",
               btn, g_irq);
        ret = g_irq;
        goto err_free_gpio;
    }

    /* request_irq：注册中断处理函数，下降沿触发（引脚接 GND + 内部上拉场景）*/
    ret = request_irq(g_irq, debris_gpio_isr, IRQF_TRIGGER_FALLING,
                      "debris_btn", dev);
    if (ret) {
        pr_err("debris: request_irq(%d) failed: %d\n", g_irq, ret);
        goto err_free_gpio;
    }

    g_active_gpio = btn;
    pr_info("debris: GPIO%d -> IRQ%d registered (falling edge triggered)\n", btn, g_irq);
    return 0;

err_free_gpio: /* gpio_request 之后、request_irq 成功之前的局部回滚 */
    gpio_free(btn); /* gpio_free：释放已申请的 GPIO */
    g_irq = -1;
    g_active_gpio = -1;
    return ret;
}

void debris_gpio_exit(struct debris_dev_data *dev)
{
    if (g_active_gpio < 0 || g_irq < 0)
        return;

    /* 顺序很关键：先 free_irq 确保 ISR 不再触发，
     * 再 cancel_work_sync 等待在途下半部跑完，最后 gpio_free */
    free_irq(g_irq, dev);          /* free_irq：注销中断处理函数 */
    cancel_work_sync(&debris_gpio_work);  /* 等待并取消已调度的 work */
    gpio_free(g_active_gpio);      /* gpio_free：归还 GPIO 所有权 */
    g_irq = -1;
    g_active_gpio = -1;
    pr_info("debris: GPIO IRQ released\n");
}
