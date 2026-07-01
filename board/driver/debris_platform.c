/* debris_platform.c — Phase 3: platform_driver + device-tree binding
 *
 * compatible = "debris,camera-engine"
 *
 * Optional DT properties:
 *   debris,ring-size   — override ring slot count
 *   debris,frame-size  — override bytes per frame
 *   debris,label       — human-readable label (shown in /proc/debris)
 *   debris,gpio-btn    — GPIO number for IRQ input (overrides module_param if set)
 *   debris,i2c-adapter — I2C bus number for sensor (e.g. 2 for OV5647 on J2)
 *   debris,sensor-addr   — sensor 7-bit I2C address (e.g. 0x36)
 *   debris,camera-count  — number of cameras (1 default, max 2)
 *   debris,cam1-i2c-adapter / debris,cam1-sensor-addr — second camera (optional)
 *   reg / ranges       — optional MMIO; devm_ioremap_resource when present
 *
 * Fallback: insmod registers a synthetic platform_device when no DT node exists
 * (module_param register_fallback_pdev=1, default on).
 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/mod_devicetable.h>
#include <linux/string.h>
#include "debris.h"

#define DEBRIS_COMPAT    "debris,camera-engine"

/* 无 DT 节点时注册合成 platform_device，保持 insmod 即可用 */
static int register_fallback_pdev = 1;
module_param(register_fallback_pdev, int, 0444);
MODULE_PARM_DESC(register_fallback_pdev,
    "Register synthetic platform device when no DT node (default 1)");

static struct platform_device *fallback_pdev;
static bool driver_registered;

static int debris_parse_dt(struct platform_device *pdev,
                           struct debris_platform_info *plat)
{
    u32 val;
    struct device *dev = &pdev->dev;

    plat->dt_bound = true;
    plat->gpio_btn = -1;
    plat->i2c_adapter = -1;
    plat->sensor_addr = -1;
    plat->camera_count = 1;
    plat->cam1_i2c_adapter = -1;
    plat->cam1_sensor_addr = -1;

    /* device_property_read_u32：从 DT 读取自定义属性 */
    if (!device_property_read_u32(dev, "debris,ring-size", &val))
        plat->ring_size = val;
    if (!device_property_read_u32(dev, "debris,frame-size", &val))
        plat->frame_size = val;

    {
        const char *lbl;

        if (!device_property_read_string(dev, "debris,label", &lbl))
            strlcpy(plat->label, lbl, sizeof(plat->label));
    }

    if (!device_property_read_u32(dev, "debris,gpio-btn", &val))
        plat->gpio_btn = (int)val;
    if (!device_property_read_u32(dev, "debris,i2c-adapter", &val))
        plat->i2c_adapter = (int)val;
    if (!device_property_read_u32(dev, "debris,sensor-addr", &val))
        plat->sensor_addr = (int)val;
    if (!device_property_read_u32(dev, "debris,camera-count", &val)) {
        if (val >= 1 && val <= 2)
            plat->camera_count = val;
    }
    if (!device_property_read_u32(dev, "debris,cam1-i2c-adapter", &val))
        plat->cam1_i2c_adapter = (int)val;
    if (!device_property_read_u32(dev, "debris,cam1-sensor-addr", &val))
        plat->cam1_sensor_addr = (int)val;
    return 0;
}

static int debris_map_mmio(struct platform_device *pdev,
                           struct debris_platform_info *plat)
{
    struct resource *res;

    /* platform_get_resource：获取 DT reg 描述的第一段 MMIO */
    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    if (!res) {
        plat->mmio_phys = 0;
        plat->mmio      = NULL;
        return 0;
    }

    /* devm_ioremap_resource：映射 MMIO，devm 自动释放 */
    plat->mmio = devm_ioremap_resource(&pdev->dev, res);
    if (IS_ERR(plat->mmio)) {
        pr_warn("debris: MMIO map failed, continue without MMIO\n");
        plat->mmio_phys = 0;
        plat->mmio      = NULL;
        return 0;
    }

    plat->mmio_phys = res->start;
    pr_info("debris: MMIO mapped phys=0x%pa\n", &plat->mmio_phys);
    return 0;
}

static int debris_plat_probe(struct platform_device *pdev)
{
    struct debris_platform_info *plat;
    struct device *dev = &pdev->dev;
    int ret;

    /* devm_kzalloc：分配 platform 私有数据，remove 时自动释放 */
    plat = devm_kzalloc(dev, sizeof(*plat), GFP_KERNEL);
    if (!plat)
        return -ENOMEM;

    plat->gpio_btn = -1;
    plat->i2c_adapter = -1;
    plat->sensor_addr = -1;
    plat->camera_count = 1;
    plat->cam1_i2c_adapter = -1;
    plat->cam1_sensor_addr = -1;
    strlcpy(plat->label, "debris-camera", sizeof(plat->label));

    /* 默认取 insmod module_param，DT 属性可覆盖 */
    debris_get_module_params(&plat->ring_size, &plat->frame_size);

    if (dev->of_node) {
        debris_parse_dt(pdev, plat);
    } else {
        plat->dt_bound = false;
        plat->i2c_adapter = -1;
        plat->sensor_addr = -1;
        plat->camera_count = 1;
        plat->cam1_i2c_adapter = -1;
        plat->cam1_sensor_addr = -1;
    }

    debris_map_mmio(pdev, plat);

    platform_set_drvdata(pdev, plat);

    ret = debris_device_register(dev, plat);
    if (ret < 0)
        return ret;

    pr_info("debris: platform probe OK (compatible=%s, label=%s)\n",
            DEBRIS_COMPAT, plat->label);
    return 0;
}

static int debris_plat_remove(struct platform_device *pdev)
{
    debris_device_unregister();
    platform_set_drvdata(pdev, NULL);
    pr_info("debris: platform remove OK\n");
    return 0;
}

static const struct of_device_id debris_of_match[] = {
    { .compatible = DEBRIS_COMPAT },
    { }
};
MODULE_DEVICE_TABLE(of, debris_of_match);

static const struct platform_device_id debris_plat_ids[] = {
    { .name = "debris-camera-engine", .driver_data = 0 },
    { }
};
MODULE_DEVICE_TABLE(platform, debris_plat_ids);

static struct platform_driver debris_plat_driver = {
    .probe  = debris_plat_probe,
    .remove = debris_plat_remove,
    .id_table = debris_plat_ids,
    .driver = {
        .name           = "debris-camera-engine",
        .of_match_table = debris_of_match,
    },
};

int debris_platform_register(void)
{
    int ret;

    ret = platform_driver_register(&debris_plat_driver);
    if (ret) {
        pr_err("debris: platform_driver_register failed, err=%d\n", ret);
        return ret;
    }
    driver_registered = true;

#if IS_ENABLED(CONFIG_OF)
    if (register_fallback_pdev &&
        !of_find_compatible_node(NULL, NULL, DEBRIS_COMPAT)) {
#else
    if (register_fallback_pdev) {
#endif
        /* platform_device_register_simple：无 DT 时按 name 匹配 id_table */
        fallback_pdev = platform_device_register_simple("debris-camera-engine",
                                                        PLATFORM_DEVID_NONE,
                                                        NULL, 0);
        if (IS_ERR(fallback_pdev)) {
            ret = PTR_ERR(fallback_pdev);
            pr_err("debris: fallback platform_device failed, err=%d\n", ret);
            platform_driver_unregister(&debris_plat_driver);
            driver_registered = false;
            return ret;
        }
        pr_info("debris: fallback platform_device registered\n");
    }

    return 0;
}

void debris_platform_unregister(void)
{
    if (fallback_pdev) {
        platform_device_unregister(fallback_pdev);
        fallback_pdev = NULL;
    }
    if (driver_registered) {
        platform_driver_unregister(&debris_plat_driver);
        driver_registered = false;
    }
}
