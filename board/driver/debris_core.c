/* debris_core.c — 字符设备注册 / 全局实例 / 模块入口 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include "debris.h"
#include "debris_fops.h"

/* ─── 全局设备实例 ────────────────────────────────────────────── */
static struct debris_dev_data gdev;
static bool gdev_registered;

/* ─── 模块参数（insmod 默认值；DT 属性可覆盖）────────────────── */
static unsigned int ring_size  = DEFAULT_RING_SIZE;
static unsigned int frame_size = DEFAULT_FRAME_SIZE;

module_param(ring_size, uint, 0444);
MODULE_PARM_DESC(ring_size,
    "Ring slot count; one slot reserved, usable capacity = ring_size-1 (default 4, range 2-64)");
module_param(frame_size, uint, 0444);
MODULE_PARM_DESC(frame_size,
    "Max bytes per frame (default 128, range 1-4096)");

struct debris_dev_data *debris_get_data(void)
{
    return &gdev;
}

static void debris_clamp_params(unsigned int *rs, unsigned int *fs)
{
    if (*rs < MIN_RING_SIZE)
        *rs = MIN_RING_SIZE;
    if (*rs > MAX_RING_SIZE)
        *rs = MAX_RING_SIZE;
    if (*fs < MIN_FRAME_SIZE)
        *fs = MIN_FRAME_SIZE;
    if (*fs > MAX_FRAME_SIZE)
        *fs = MAX_FRAME_SIZE;
}

void debris_get_module_params(unsigned int *ring_sz, unsigned int *frame_sz)
{
    *ring_sz  = ring_size;
    *frame_sz = frame_size;
    debris_clamp_params(ring_sz, frame_sz);
}

/* ─── 设备注册（由 platform probe 调用）────────────────────────── */
int debris_device_register(struct device *parent, struct debris_platform_info *plat)
{
    unsigned int rs, fs;
    int ret;

    if (gdev_registered) {
        pr_err("debris: device already registered\n");
        return -EBUSY;
    }

    if (plat) {
        rs = plat->ring_size;
        fs = plat->frame_size;
    } else {
        rs = ring_size;
        fs = frame_size;
    }
    debris_clamp_params(&rs, &fs);

    memset(&gdev, 0, sizeof(gdev));
    gdev.dev  = parent;
    gdev.plat = plat;

    /* spin_lock_init：初始化 ring 保护锁 */
    spin_lock_init(&gdev.slock);
    init_waitqueue_head(&gdev.wq);
    debris_motion_init(&gdev);

    /* ring_alloc：按运行时参数分配环形缓冲 */
    ret = ring_alloc(&gdev.ring, rs, fs);
    if (ret < 0) {
        pr_err("debris: ring_alloc failed, err=%d\n", ret);
        return ret;
    }

    /* alloc_chrdev_region：分配字符设备号 */
    ret = alloc_chrdev_region(&gdev.devno, 0, 1, "debris_kernel");
    if (ret < 0) {
        pr_err("debris: alloc_chrdev_region failed, err=%d\n", ret);
        goto err_ring_free;
    }

    cdev_init(&gdev.cdev, &debris_fops);
    gdev.cdev.owner = THIS_MODULE;
    ret = cdev_add(&gdev.cdev, gdev.devno, 1);
    if (ret < 0) {
        pr_err("debris: cdev_add failed, err=%d\n", ret);
        goto err_unreg_region;
    }

    gdev.cls = class_create(THIS_MODULE, "debris_class");
    if (IS_ERR(gdev.cls)) {
        ret = PTR_ERR(gdev.cls);
        goto err_cdev_del;
    }
    if (IS_ERR(device_create(gdev.cls, parent, gdev.devno, NULL, "debris_kernel"))) {
        ret = -EINVAL;
        goto err_class_destroy;
    }

    ret = debris_proc_init(&gdev);
    if (ret < 0)
        goto err_device_destroy; /* proc 未创建，勿 proc_exit */

    ret = debris_irq_init(&gdev);
    if (ret < 0)
        goto err_proc_exit; /* irq 未完成，勿 irq_exit */

    ret = debris_gpio_init(&gdev);
    if (ret < 0)
        goto err_irq_exit; /* gpio 未完成，勿 gpio_exit */

    ret = debris_i2c_init(&gdev);
    if (ret < 0)
        goto err_i2c_exit;

    gdev_registered = true;
    pr_info("debris: ready, ring=%ux%u bytes (capacity %u frames)\n",
            gdev.ring.size, gdev.ring.frame_sz, gdev.ring.size - 1);
    return 0;

/* 逆序回滚：仅释放已成功初始化的子模块（fall-through） */
err_i2c_exit:
    debris_i2c_exit(&gdev);
err_gpio_exit: /* 仅由 err_i2c_exit 落入 */
    debris_gpio_exit(&gdev);
err_irq_exit:
    debris_irq_exit(&gdev);
err_proc_exit:
    debris_proc_exit(&gdev);
err_device_destroy:
    device_destroy(gdev.cls, gdev.devno);
err_class_destroy:
    class_destroy(gdev.cls);
err_cdev_del:
    cdev_del(&gdev.cdev);
err_unreg_region:
    unregister_chrdev_region(gdev.devno, 1);
err_ring_free:
    ring_free(&gdev.ring);
    gdev.dev  = NULL;
    gdev.plat = NULL;
    return ret;
}

void debris_device_unregister(void) {
    if (!gdev_registered) {
        return;
    }
    
    debris_i2c_exit(&gdev);
    debris_gpio_exit(&gdev);
    debris_irq_exit(&gdev);
    debris_proc_exit(&gdev);
    device_destroy(gdev.cls, gdev.devno);
    class_destroy(gdev.cls);
    cdev_del(&gdev.cdev);
    unregister_chrdev_region(gdev.devno, 1);
    ring_free(&gdev.ring);

    gdev.dev  = NULL;
    gdev.plat = NULL;
    gdev_registered = false;
    pr_info("debris: device unregistered\n");
}

/* ─── 模块入口：仅注册 platform 驱动（probe 中完成设备注册）────── */
static int __init debris_init(void) {
    return debris_platform_register();
}

static void __exit debris_exit(void) {
    debris_platform_unregister();
}

module_init(debris_init);
module_exit(debris_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Adrian");
MODULE_DESCRIPTION("Progressive Driver Learning Project - milkv-duo-s");
MODULE_VERSION("0.3");
