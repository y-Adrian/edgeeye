#include <linux/module.h>
#include <linux/i2c.h>
#include "debris.h"
#include "debris_ov5647_regs.h"

#define OV5647_SW_RESET           0x0103
#define OV5647_SW_STANDBY         0x0100
#define OV5647_REG_CHIPID_H       0x300a
#define OV5647_REG_CHIPID_L       0x300b
#define OV5647_REG_X_OUTPUT_H     0x3808
#define OV5647_REG_X_OUTPUT_L     0x3809
#define OV5647_REG_Y_OUTPUT_H     0x380a
#define OV5647_REG_Y_OUTPUT_L     0x380b
#define DEBRIS_I2C_ADAPTER_DEFAULT 2
#define DEBRIS_SENSOR_ADDR_DEFAULT 0x36
#define DEBRIS_OV5647_WIDTH       640
#define DEBRIS_OV5647_HEIGHT      480

static struct i2c_adapter *i2c_adap;
static struct i2c_adapter *i2c_adap_cam1;
static int i2c_adapter_nr = -1;
static int i2c_addr = -1;
static int resolved_i2c_adapter;
static int resolved_i2c_addr;
static int resolved_cam1_adapter;
static int resolved_cam1_addr;
static u16 sensor_chip_id;
static u16 cam1_chip_id;
static bool i2c_ok;
static bool cam1_i2c_ok;
static bool sensor_reset_ok;
static bool sensor_init_ok;
static u8 sensor_sw_standby;
static u16 sensor_width;
static u16 sensor_height;

static int i2c_sensor_mode = 1;

module_param(i2c_adapter_nr, int, 0444);
MODULE_PARM_DESC(i2c_adapter_nr,
    "I2C adapter number (-1=DT/default 2 for OV5647 on Duo S J2)");
module_param(i2c_addr, int, 0444);
MODULE_PARM_DESC(i2c_addr, "Sensor 7-bit I2C address (-1=DT/default 0x36)");
module_param(i2c_sensor_mode, int, 0444);
MODULE_PARM_DESC(i2c_sensor_mode,
    "1=probe+reset+640x480 mode (learning); 0=Chip ID only, for vendor RTSP coexist");

static void debris_i2c_fail_cleanup(void)
{
    if (i2c_adap_cam1 && i2c_adap_cam1 != i2c_adap) {
        i2c_put_adapter(i2c_adap_cam1);
        i2c_adap_cam1 = NULL;
    }
    if (i2c_adap) {
        i2c_put_adapter(i2c_adap);
        i2c_adap = NULL;
    }
    i2c_ok = false;
    cam1_i2c_ok = false;
    sensor_reset_ok = false;
    sensor_init_ok = false;
}

static void debris_resolve_i2c_config(struct debris_dev_data *dev)
{
    if (i2c_adapter_nr >= 0)
        resolved_i2c_adapter = i2c_adapter_nr;
    else if (dev && dev->plat && dev->plat->i2c_adapter >= 0)
        resolved_i2c_adapter = dev->plat->i2c_adapter;
    else
        resolved_i2c_adapter = DEBRIS_I2C_ADAPTER_DEFAULT;

    if (i2c_addr >= 0)
        resolved_i2c_addr = i2c_addr;
    else if (dev && dev->plat && dev->plat->sensor_addr >= 0)
        resolved_i2c_addr = dev->plat->sensor_addr;
    else
        resolved_i2c_addr = DEBRIS_SENSOR_ADDR_DEFAULT;

    resolved_cam1_adapter = -1;
    resolved_cam1_addr = -1;
    if (dev && dev->plat && dev->plat->camera_count >= 2) {
        if (dev->plat->cam1_i2c_adapter >= 0)
            resolved_cam1_adapter = dev->plat->cam1_i2c_adapter;
        if (dev->plat->cam1_sensor_addr >= 0)
            resolved_cam1_addr = dev->plat->cam1_sensor_addr;
    }
}

static int debris_i2c_read_reg(struct i2c_adapter *adap, int addr,
                               u16 reg, u8 *val)
{
    u8 reg_be[2] = { reg >> 8, reg & 0xff };
    struct i2c_msg msgs[2];
    int ret;

    if (!adap || !val)
        return -EINVAL;

    msgs[0].addr  = addr;
    msgs[0].flags = 0;
    msgs[0].len   = 2;
    msgs[0].buf   = reg_be;

    msgs[1].addr  = addr;
    msgs[1].flags = I2C_M_RD;
    msgs[1].len   = 1;
    msgs[1].buf   = val;

    ret = i2c_transfer(adap, msgs, 2);
    if (ret != 2)
        return ret < 0 ? ret : -EIO;
    return 0;
}

static int debris_i2c_write_reg(struct i2c_adapter *adap, int addr,
                                u16 reg, u8 val)
{
    u8 buf[3] = { reg >> 8, reg & 0xff, val };
    struct i2c_msg msg = {
        .addr  = addr,
        .flags = 0,
        .len   = 3,
        .buf   = buf,
    };
    int ret;

    if (!adap)
        return -EINVAL;

    ret = i2c_transfer(adap, &msg, 1);
    if (ret != 1)
        return ret < 0 ? ret : -EIO;
    return 0;
}

static int debris_ov5647_read_reg(u16 reg, u8 *val)
{
    return debris_i2c_read_reg(i2c_adap, resolved_i2c_addr, reg, val);
}

static int debris_ov5647_write_reg(u16 reg, u8 val)
{
    return debris_i2c_write_reg(i2c_adap, resolved_i2c_addr, reg, val);
}

static int debris_ov5647_write_table(const struct debris_ov5647_reg *regs,
                                     unsigned int count)
{
    unsigned int i;
    int ret;

    for (i = 0; i < count; i++) {
        ret = debris_ov5647_write_reg(regs[i].reg, regs[i].val);
        if (ret < 0) {
            pr_err("debris: write reg 0x%04x failed: %d\n", regs[i].reg, ret);
            return ret;
        }
    }
    return 0;
}

static int debris_ov5647_read_output_size(u16 *width, u16 *height)
{
    u8 hi, lo;
    int ret;

    ret = debris_ov5647_read_reg(OV5647_REG_X_OUTPUT_H, &hi);
    if (ret < 0)
        return ret;
    ret = debris_ov5647_read_reg(OV5647_REG_X_OUTPUT_L, &lo);
    if (ret < 0)
        return ret;
    *width = ((u16)hi << 8) | lo;

    ret = debris_ov5647_read_reg(OV5647_REG_Y_OUTPUT_H, &hi);
    if (ret < 0)
        return ret;
    ret = debris_ov5647_read_reg(OV5647_REG_Y_OUTPUT_L, &lo);
    if (ret < 0)
        return ret;
    *height = ((u16)hi << 8) | lo;

    return 0;
}

static int debris_ov5647_load_mode_640x480(void)
{
    int ret;

    ret = debris_ov5647_write_table(debris_ov5647_mode_640x480,
                                    debris_ov5647_mode_640x480_len);
    if (ret < 0)
        return ret;

    ret = debris_ov5647_read_reg(OV5647_SW_STANDBY, &sensor_sw_standby);
    if (ret < 0)
        return ret;
    if (!(sensor_sw_standby & 0x01)) {
        pr_err("debris: mode table loaded but SW_STANDBY=0x%02x\n",
               sensor_sw_standby);
        return -EIO;
    }

    ret = debris_ov5647_read_output_size(&sensor_width, &sensor_height);
    if (ret < 0)
        return ret;
    if (sensor_width != DEBRIS_OV5647_WIDTH ||
        sensor_height != DEBRIS_OV5647_HEIGHT) {
        pr_err("debris: output size %ux%u, expected %ux%u\n",
               sensor_width, sensor_height,
               DEBRIS_OV5647_WIDTH, DEBRIS_OV5647_HEIGHT);
        return -EIO;
    }

    sensor_init_ok = true;
    pr_info("debris: OV5647 640x480 mode table loaded (%ux%u active)\n",
            sensor_width, sensor_height);
    return 0;
}

static int debris_cam1_probe_chip_id(struct debris_dev_data *dev)
{
    u8 id_h, id_l;
    int ret;

    if (resolved_cam1_adapter < 0 || resolved_cam1_addr < 0)
        return 0;

    if (resolved_cam1_adapter == resolved_i2c_adapter)
        i2c_adap_cam1 = i2c_adap;
    else
        i2c_adap_cam1 = i2c_get_adapter(resolved_cam1_adapter);

    if (!i2c_adap_cam1) {
        pr_warn("debris: cam1 i2c_get_adapter(%d) failed\n",
                resolved_cam1_adapter);
        return 0;
    }

    ret = debris_i2c_read_reg(i2c_adap_cam1, resolved_cam1_addr,
                              OV5647_REG_CHIPID_H, &id_h);
    if (ret < 0) {
        pr_warn("debris: cam1 read CHIPID_H failed: %d\n", ret);
        goto cam1_put;
    }

    ret = debris_i2c_read_reg(i2c_adap_cam1, resolved_cam1_addr,
                              OV5647_REG_CHIPID_L, &id_l);
    if (ret < 0) {
        pr_warn("debris: cam1 read CHIPID_L failed: %d\n", ret);
        goto cam1_put;
    }

    if (id_h != 0x56 || id_l != 0x47) {
        pr_warn("debris: cam1 chip ID mismatch: %02x%02x\n", id_h, id_l);
        goto cam1_put;
    }

    cam1_chip_id = (id_h << 8) | id_l;
    cam1_i2c_ok = true;
    pr_info("debris: cam1 OV5647 chip ID OK (0x%04x) adapter=%d addr=0x%02x\n",
            cam1_chip_id, resolved_cam1_adapter, resolved_cam1_addr);
    return 0;

cam1_put:
    if (i2c_adap_cam1 && i2c_adap_cam1 != i2c_adap) {
        i2c_put_adapter(i2c_adap_cam1);
        i2c_adap_cam1 = NULL;
    }
    return 0;
}

int debris_i2c_init(struct debris_dev_data *dev)
{
    int ret;
    u8 id_h, id_l;

    debris_resolve_i2c_config(dev);

    i2c_adap = i2c_get_adapter(resolved_i2c_adapter);
    if (!i2c_adap) {
        pr_err("debris: i2c_get_adapter(%d) failed\n", resolved_i2c_adapter);
        return -ENODEV;
    }
    pr_info("debris: I2C adapter %d OK (%s), addr=0x%02x\n",
            resolved_i2c_adapter, i2c_adap->name, resolved_i2c_addr);

    ret = debris_ov5647_read_reg(OV5647_REG_CHIPID_H, &id_h);
    if (ret < 0) {
        pr_err("debris: read CHIPID_H failed: %d\n", ret);
        debris_i2c_fail_cleanup();
        return ret;
    }

    ret = debris_ov5647_read_reg(OV5647_REG_CHIPID_L, &id_l);
    if (ret < 0) {
        pr_err("debris: read CHIPID_L failed: %d\n", ret);
        debris_i2c_fail_cleanup();
        return ret;
    }

    if (id_h != 0x56 || id_l != 0x47) {
        pr_err("debris: OV5647 chip ID mismatch: %02x%02x\n", id_h, id_l);
        debris_i2c_fail_cleanup();
        return -ENODEV;
    }

    sensor_chip_id = (id_h << 8) | id_l;
    i2c_ok = true;
    pr_info("debris: OV5647 chip ID OK (0x%04x)\n", sensor_chip_id);

    if (!i2c_sensor_mode) {
        pr_info("debris: i2c_sensor_mode=0, skip reset/mode (vendor RTSP safe)\n");
        debris_cam1_probe_chip_id(dev);
        return 0;
    }

    ret = debris_ov5647_write_reg(OV5647_SW_RESET, 0x01);
    if (ret < 0) {
        pr_err("debris: OV5647 soft reset assert failed: %d\n", ret);
        debris_i2c_fail_cleanup();
        return ret;
    }

    ret = debris_ov5647_write_reg(OV5647_SW_RESET, 0x00);
    if (ret < 0) {
        pr_err("debris: OV5647 soft reset deassert failed: %d\n", ret);
        debris_i2c_fail_cleanup();
        return ret;
    }
    pr_info("debris: OV5647 soft reset OK\n");

    sensor_reset_ok = true;

    ret = debris_ov5647_load_mode_640x480();
    if (ret < 0) {
        pr_err("debris: OV5647 mode init failed: %d\n", ret);
        debris_i2c_fail_cleanup();
        return ret;
    }

    debris_cam1_probe_chip_id(dev);
    return 0;
}

void debris_i2c_exit(struct debris_dev_data *dev)
{
    if (i2c_adap_cam1 && i2c_adap_cam1 != i2c_adap) {
        i2c_put_adapter(i2c_adap_cam1);
        i2c_adap_cam1 = NULL;
    }
    if (i2c_adap) {
        i2c_put_adapter(i2c_adap);
        i2c_adap = NULL;
        pr_info("debris: I2C adapter released\n");
    }
    cam1_i2c_ok = false;
}

void debris_i2c_get_status(bool *ok, u16 *chip_id, int *adap_nr, int *addr,
                           bool *reset_ok, u8 *sw_standby)
{
    if (ok)
        *ok = i2c_ok;
    if (chip_id)
        *chip_id = sensor_chip_id;
    if (adap_nr)
        *adap_nr = resolved_i2c_adapter;
    if (addr)
        *addr = resolved_i2c_addr;
    if (reset_ok)
        *reset_ok = sensor_reset_ok;
    if (sw_standby)
        *sw_standby = sensor_sw_standby;
}

void debris_i2c_get_sensor_mode(bool *init_ok, u16 *width, u16 *height)
{
    if (init_ok)
        *init_ok = sensor_init_ok;
    if (width)
        *width = sensor_width;
    if (height)
        *height = sensor_height;
}

void debris_i2c_get_cam1_status(bool *ok, u16 *chip_id, int *adap_nr, int *addr)
{
    if (ok)
        *ok = cam1_i2c_ok;
    if (chip_id)
        *chip_id = cam1_chip_id;
    if (adap_nr)
        *adap_nr = resolved_cam1_adapter;
    if (addr)
        *addr = resolved_cam1_addr;
}
