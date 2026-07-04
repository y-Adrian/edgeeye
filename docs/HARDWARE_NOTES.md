# Milk-V Duo S Hardware Notes

## Board

- SoC: SG2000 (C906 RISC-V + Cortex-A53)
- Board: Milk-V Duo S
- USB network: `192.168.42.1`, user `root`

## GPIO map (from `/sys/kernel/debug/gpio`)

| gpiochip | Global range | Bank   | IRQ capable |
|----------|--------------|--------|-------------|
| gpiochip0 | 480–511     | XGPIOA | yes         |
| gpiochip1 | 448–479     | XGPIOB | yes         |
| gpiochip2 | 416–447     | XGPIOC | unknown     |
| gpiochip3 | 384–415     | XGPIOD | unknown     |
| gpiochip4 | 352–383     | PWR_GPIO | unknown   |

Formula: global GPIO = chip base + line offset (e.g. A20 = 480 + 20 = 500).

## Header pins for learning (40-pin)

| Label | Global GPIO | Header use        | Notes                    |
|-------|-------------|-------------------|--------------------------|
| A20   | 500         | IRQ input (button)| recommended, IRQ-capable |
| A28   | 508         | IRQ loopback out  | drive A20 for test       |
| A16   | 496         | avoid             | UART0_TX console         |
| A17   | 487         | avoid             | UART0_RX console         |

## Cameras (project target)

| Model        | Interface | Notes                          |
|--------------|-----------|--------------------------------|
| GC2083       | MIPI CSI  | Milk-V official 2MP module     |
| OV5647       | MIPI CSI  | Raspberry Pi compatible module |

Sensor control is via I2C (Phase 4). CSI/ISP/VICAP host nodes come from vendor BSP.

## Dual cameras on board (confirmed 2026-06-05)

Both **J1** and **J2** are populated on the project board.

| CSI | I2C | Addr | Model | `sensor_cfg` on `/mnt/data` |
|-----|-----|------|-------|-----------------------------|
| **J2** | i2c-2 | **0x36** | OV5647 (Raspberry Pi module) | `sensor_cfg_OV5647_J2.ini` |
| **J1** | i2c-3 | **0x37** | GC2083 (Milk-V official) | `sensor_cfg_GC2083.ini` |

**双摄混搭**（edgeeye_cam `--dual`）：`sensor_cfg_GC2083_OV5647_dual.ini`（`dev_num=2`）。

**PQ bin：** pipe0 ← `cvi_sdr_bin_GC2083`；pipe1 ← `cvi_sdr_bin_OV5647.bin`（双摄 per-pipe 加载，见 `cam_isp_tuning.c`）。

## Camera bring-up (Week 0, on-board scan)

Last updated: dual cam above; OV5647 Chip ID **0x5647** on i2c-2 verified earlier. See [PROJECT_STATUS.md](./PROJECT_STATUS.md).

### I2C scan (`i2cdetect -y`)

| Adapter | Detected addresses | Notes |
|---------|-------------------|--------|
| i2c-1 | (none) | empty |
| i2c-2 | **0x36** | J2 — OV5647 |
| i2c-3 | **0x37** | J1 — GC2083 |
| i2c-4 | (none) | empty (gt9xx touch at 0x14 only in sysfs) |

Tool warning `Can't use SMBus Quick Write` is benign; `0x36` on i2c-2 is still valid.

### sysfs I2C devices

```text
1-003d  2-003d  3-003d  4-0014  4-003d
names:  sensor_i2c (x4), gt9xx (4-0014)
```

| Node | Name | Role |
|------|------|------|
| `1-003d`, `2-003d`, `3-003d`, `4-003d` | `sensor_i2c` | BSP vendor sensor I2C client @ **0x3d** (not the same as physical **0x36**) |
| `4-0014` | `gt9xx` | touch panel |
| *(missing)* | — | no `2-0036` → **no kernel client bound at 0x36** yet |

**Implication:** physical sensor is on **i2c-2 / 0x36**. BSP **`sensor_i2c @ 0x3d`** on multiple buses is a separate vendor client (RESOURCES: J1/J2 CSI ports use I2C3/I2C2 respectively). Phase 4 code goes in **`debris_i2c.c` inside `debris.ko`**, using `i2c_get_adapter(2)` + transfers to **0x36** — do not bind to `x-003d`.

### Chip ID

OV5647 confirmed on **i2c-2 / 0x36** (2025 on-board read):

```bash
i2ctransfer -y 2 w2@0x36 0x30 0x0a r1   # → 0x56
i2ctransfer -y 2 w2@0x36 0x30 0x0b r1   # → 0x47
```

Combined ID: **0x5647** (OV5647).

### BSP `sensor_i2c @ 0x3d`

```bash
ls -l /sys/bus/i2c/devices/2-003d/driver
# → No such file (device node exists, no bound driver symlink)
```

`2-003d` is present as `sensor_i2c` but **not driver-bound** in sysfs. Physical access for learning uses **0x36** directly; low conflict risk for Step 2 adapter + transfer approach.

### Video / media stack

| Check | Result |
|-------|--------|
| `/dev/video*`, `/dev/media*` | **none** |
| `v4l2-ctl --list-devices` | no output |
| `media-ctl -p` | no output |
| Loaded modules | `cvi_mipi_rx`, `cv181x_vi`, `snsr_i2c`, `cvi_vc_driver`, `cv181x_base`, … |

Media kernel modules are loaded; **V4L2 nodes not created** until vendor pipeline/sample is started (typical for CVITEK BSP).

### dmesg (sensor keywords)

```bash
dmesg | grep -iE '5647|sensor|snsr|mipi' | tail -30
```

No useful sensor/OV5647/MIPI lines in current boot log (only unrelated WiFi log may appear). **Do not treat empty dmesg as “no camera”.** Use Chip ID + `i2cdetect` instead.

### Phase 4 coding plan (`debris.ko`)

| Item | Value |
|------|--------|
| File | `board/driver/debris_i2c.c` (hook like `debris_gpio.c`) |
| `adapter_nr` | 2 |
| `i2c_addr` (7-bit) | 0x36 |
| ID regs | 0x300A → 0x56, 0x300B → 0x47 |
| Reference | `duo-sdk/linux_5.10/drivers/media/i2c/ov5647.c` |

Next code step: wire `debris_i2c_init` / `debris_i2c_exit` in `debris_core.c`, then add Chip ID read.

## Phase 3 platform driver

- compatible: `debris,camera-engine`
- DTS fragment: `board/dts/debris-camera-engine.dtsi`
- Without DTS patch: `insmod debris.ko` uses fallback platform device (default)
- With DTS node: set `register_fallback_pdev=0` to avoid duplicate probe

Verify on board:

```bash
cat /proc/debris          # dt_bound, dt_label, mmio_phys, gpio_btn_dt
cat /proc/device-tree/debris-camera/compatible   # after DTS merge
```
