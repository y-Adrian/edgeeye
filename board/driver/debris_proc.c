/* debris_proc.c — Phase 1: procfs + debugfs 接口
 *
 * 提供两个观测窗口：
 *   /proc/debris               —— seq_file，输出驱动统计
 *   /sys/kernel/debug/debris/  —— debugfs，输出更详细的内部状态
 */
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/debugfs.h>
#include "debris.h"

static struct proc_dir_entry *proc_entry;
static struct dentry         *dbg_dir;

/* ── procfs ──────────────────────────────────────────────────── */

static int debris_proc_show(struct seq_file *m, void *v)
{
    bool i2c_ok;
    u16 chip_id;
    int adap_nr, addr;
    bool reset_ok;
    u8 sw_standby;
    bool init_ok;
    u16 sensor_w, sensor_h;
    bool cam1_ok;
    u16 cam1_id;
    int cam1_adap, cam1_addr;
    struct debris_dev_data *dev = (struct debris_dev_data *)m->private;

    seq_printf(m, "read_count  : %lu\n", dev->read_count);
    seq_printf(m, "write_count : %lu\n", dev->write_count);
    seq_printf(m, "ring_used   : %u / %u\n", 
        ring_count(&dev->ring), dev->ring.size);
    seq_printf(m, "frame_size  : %u bytes\n", dev->ring.frame_sz);
    if (dev->plat) {
        seq_printf(m, "dt_bound    : %s\n", dev->plat->dt_bound ? "yes" : "no");
        seq_printf(m, "dt_label    : %s\n", dev->plat->label);
        if (dev->plat->mmio_phys) {
            seq_printf(m, "mmio_phys   : 0x%pa\n", &dev->plat->mmio_phys);
        } else {
            seq_printf(m, "mmio_phys   : none\n");
        }
        seq_printf(m, "gpio_btn_dt : %d\n", dev->plat->gpio_btn);
        if (dev->plat->i2c_adapter >= 0)
            seq_printf(m, "i2c_adapter_dt : %d\n", dev->plat->i2c_adapter);
        else
            seq_printf(m, "i2c_adapter_dt : none\n");
        if (dev->plat->sensor_addr >= 0)
            seq_printf(m, "sensor_addr_dt : 0x%02x\n", dev->plat->sensor_addr);
        else
            seq_printf(m, "sensor_addr_dt : none\n");
        seq_printf(m, "camera_count_dt  : %u\n", dev->plat->camera_count);
        if (dev->plat->cam1_i2c_adapter >= 0)
            seq_printf(m, "cam1_i2c_adapter_dt : %d\n",
                       dev->plat->cam1_i2c_adapter);
        else
            seq_printf(m, "cam1_i2c_adapter_dt : none\n");
        if (dev->plat->cam1_sensor_addr >= 0)
            seq_printf(m, "cam1_sensor_addr_dt : 0x%02x\n",
                       dev->plat->cam1_sensor_addr);
        else
            seq_printf(m, "cam1_sensor_addr_dt : none\n");
    }

    debris_i2c_get_status(&i2c_ok, &chip_id, &adap_nr, &addr,
                          &reset_ok, &sw_standby);
    seq_printf(m, "i2c_ok         : %d\n", i2c_ok ? 1 : 0);
    seq_printf(m, "i2c_adapter    : %d\n", adap_nr);
    seq_printf(m, "i2c_addr       : 0x%02x\n", addr);
    seq_printf(m, "sensor_chip_id : 0x%04x\n", chip_id);
    seq_printf(m, "sensor_reset_ok  : %d\n", reset_ok ? 1 : 0);
    seq_printf(m, "sensor_sw_standby: 0x%02x\n", sw_standby);
    debris_i2c_get_sensor_mode(&init_ok, &sensor_w, &sensor_h);
    seq_printf(m, "sensor_init_ok   : %d\n", init_ok ? 1 : 0);
    seq_printf(m, "sensor_width     : %u\n", sensor_w);
    seq_printf(m, "sensor_height    : %u\n", sensor_h);
    seq_printf(m, "motion_count     : %lu\n", dev->motion_count);
    seq_printf(m, "motion_pending   : %d\n", dev->motion_pending ? 1 : 0);
    debris_i2c_get_cam1_status(&cam1_ok, &cam1_id, &cam1_adap, &cam1_addr);
    seq_printf(m, "cam1_i2c_ok      : %d\n", cam1_ok ? 1 : 0);
    if (cam1_adap >= 0)
        seq_printf(m, "cam1_i2c_adapter : %d\n", cam1_adap);
    else
        seq_printf(m, "cam1_i2c_adapter : none\n");
    if (cam1_addr >= 0)
        seq_printf(m, "cam1_i2c_addr    : 0x%02x\n", cam1_addr);
    else
        seq_printf(m, "cam1_i2c_addr    : none\n");
    seq_printf(m, "cam1_chip_id     : 0x%04x\n", cam1_id);
    return 0;
}

static int debris_proc_open(struct inode *inode, struct file *file)
{
    return single_open(file, debris_proc_show, PDE_DATA(inode));
}

static const struct proc_ops debris_proc_ops = {
    .proc_open    = debris_proc_open,
    .proc_read    = seq_read,
    .proc_lseek   = seq_lseek,
    .proc_release = single_release,
};

/* ── debugfs ─────────────────────────────────────────────────── */

static int debris_dbg_show(struct seq_file *m, void *v)
{
    struct debris_dev_data *dev = (struct debris_dev_data *)m->private;

    seq_printf(m, "=== debris debug stats ===\n");
    seq_printf(m, "read_count  : %lu\n", dev->read_count);
    seq_printf(m, "write_count : %lu\n", dev->write_count);
    seq_printf(m, "ring_used   : %u / %u frames\n",
               ring_count(&dev->ring), dev->ring.size);
    seq_printf(m, "frame_size  : %u bytes\n", dev->ring.frame_sz);
    if (dev->plat) {
        seq_printf(m, "dt_bound    : %s\n", dev->plat->dt_bound ? "yes" : "no");
        seq_printf(m, "dt_label    : %s\n", dev->plat->label);
        if (dev->plat->mmio_phys)
            seq_printf(m, "mmio_phys   : 0x%pa\n", &dev->plat->mmio_phys);
        else
            seq_printf(m, "mmio_phys   : none\n");
    }
    return 0;
}

static int debris_dbg_open(struct inode *inode, struct file *file)
{
    return single_open(file, debris_dbg_show, inode->i_private);
}

static const struct file_operations debris_dbg_fops = {
    .open    = debris_dbg_open,
    .read    = seq_read,
    .llseek  = seq_lseek,
    .release = single_release,
};

/* ── debugfs: timer_enable（可读写）────────────────────────────── */

static ssize_t timer_enable_write(struct file *file, const char __user *ubuf,
                                   size_t count, loff_t *ppos)
{
    struct debris_dev_data *dev = file->private_data;
    char buf[4];
    size_t len = min(count, sizeof(buf) - 1);

    /* copy_from_user：从用户态读取控制字符 */
    if (copy_from_user(buf, ubuf, len))
        return -EFAULT;
    buf[len] = '\0';

    if (buf[0] == '0') {
        /* hrtimer_cancel：停止定时器并等待回调结束 */
        hrtimer_cancel(&dev->timer);
        pr_info("debris: timer stopped\n");
    } else if (buf[0] == '1') {
        /* hrtimer_start：启动定时器，33ms 后第一次触发 */
        hrtimer_start(&dev->timer, ms_to_ktime(33), HRTIMER_MODE_REL);
        pr_info("debris: timer started\n");
    }
    return count;
}

static int timer_enable_open(struct inode *inode, struct file *file)
{
    /* 把 dev 指针存入 private_data，供 write 回调使用 */
    file->private_data = inode->i_private;
    return 0;
}

static const struct file_operations timer_enable_fops = {
    .open  = timer_enable_open,
    .write = timer_enable_write,
    .llseek = no_llseek,
};

/* ── init / exit ─────────────────────────────────────────────── */

int debris_proc_init(struct debris_dev_data *dev)
{
    /* 创建 /proc/debris 条目 */
    proc_entry = proc_create_data("debris", 0444, NULL, &debris_proc_ops, dev);
    if (!proc_entry) {
        pr_err("debris: create /proc/debris failed\n");
        return -ENOMEM;
    }

    /* 创建 /sys/kernel/debug/debris 目录 */
    dbg_dir = debugfs_create_dir("debris", NULL);
    if (IS_ERR_OR_NULL(dbg_dir)) {
        pr_warn("debris: debugfs is not available\n");
        dbg_dir = NULL;
    } else {
        debugfs_create_file("stats", 0444, dbg_dir, dev, &debris_dbg_fops);
        debugfs_create_file("timer_enable", 0200, dbg_dir, dev, &timer_enable_fops);
    }

    pr_info("debris: proc/debugfs initialized successfully\n");
    return 0;
}

void debris_proc_exit(struct debris_dev_data *dev)
{
    if (dbg_dir) {
        debugfs_remove_recursive(dbg_dir); /* 递归移除 debugfs 目录及子文件 */
        dbg_dir = NULL;
    }
    if (proc_entry) {
        proc_remove(proc_entry); /* 移除 /proc/debris */
        proc_entry = NULL;
    }
}
