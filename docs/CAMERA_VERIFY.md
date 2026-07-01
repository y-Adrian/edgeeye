# 摄像头现状与逐步确认指南

> 记录板子上已摸清的硬件、配置与 RTSP 问题，后续按步骤复验。  
> 板子：Milk-V Duo S，`192.168.42.1`，用户 `root`。  
> 最后更新：**2026-06-05**（板上 `i2cdetect` + RTSP 日志）

---

## 1. 已确认的硬件（双摄像头同插）

两颗模组**同时插在 J1 + J2**，I2C 扫描结果如下：

| CSI 座 | I2C 适配器 | 7-bit 地址 | 型号 | SDK `sensor_cfg` 片段 |
|--------|------------|------------|------|------------------------|
| **J2** | **i2c-2** | **0x36** | **OV5647**（树莓派兼容模组） | `sensor_cfg_OV5647_J2.ini` |
| **J1** | **i2c-3** | **0x37** | **GC2083**（Milk-V 官方模组） | `sensor_cfg_GC2083.ini` |

### 板上复现扫描

```bash
i2cdetect -y 2    # J2 → 应见 0x36
i2cdetect -y 3    # J1 → 应见 0x37
```

`Can't use SMBus Quick Write` 警告可忽略，地址仍有效。

### Chip ID 核对（可选）

```bash
# OV5647 @ J2
i2ctransfer -y 2 w2@0x36 0x30 0x0a r1   # 期望 0x56
i2ctransfer -y 2 w2@0x36 0x30 0x0b r1   # 期望 0x47  → 合为 0x5647

# GC2083 @ J1
i2ctransfer -y 3 w2@0x37 0x03 0xf0 r1   # 期望 0x20
i2ctransfer -y 3 w2@0x37 0x03 0xf1 r1   # 期望 0x83  → 合为 0x2083
```

### MIPI / lane（来自 SDK ini，未在板上逐线实测）

| 座 | `mipi_dev` | `lane_id` | `sns_i2c_addr`（ini 十进制） |
|----|------------|-----------|------------------------------|
| J2 OV5647 | 1 | 5, 3, 4, -1, -1 | 36 |
| J1 GC2083 | 0 | 2, 0, 1, -1, -1 | 37 |

---

## 2. 软件与配置文件

### `sensor_cfg.ini` 软链（决定 RTSP 用哪颗头）

| 场景 | 命令 / 脚本 | `dev_num` | 启用的传感器 |
|------|-------------|-----------|--------------|
| 默认单摄（学习/安全脚本） | `rtsp_preview_only.sh`、`run_security.sh` | 1 | 仅 **J2 OV5647** |
| 官方头单摄 | `ln -sf .../sensor_cfg_GC2083.ini sensor_cfg.ini` | 1 | 仅 **J1 GC2083** |
| 双摄模板（**不适用本板**） | `sensor_cfg_OV5647_dual.ini` | 2 | 假定 J1+J2 **都是 OV5647** |

本板为 **GC2083 + OV5647 混搭**，仓库里**没有**现成的混搭双摄 ini；要双路 RTSP 需自定义 `sensor_cfg` + 双传感器 PQ bin。

### ISP PQ bin（`/mnt/cfg/param/`）

```text
cvi_sdr_bin              # 软链，ISP 实际加载此路径
cvi_sdr_bin_GC2083       # J1 GC2083（PQ 元数据 sensor id 2053）
cvi_sdr_bin_OV5647.bin   # J2 OV5647（sensor id 22087 / 0x5647）
cvi_sdr_bin_SC035HGS     # 其他模组
```

**出厂默认：** `cvi_sdr_bin` → `cvi_sdr_bin_GC2083`。

- 用 **OV5647** 时必须改为 → `cvi_sdr_bin_OV5647.bin`，否则 `22087 vs 2053` mismatch + 黑屏。
- 用 **GC2083** 时保持 → `cvi_sdr_bin_GC2083`。
- SDK 源：`duo-sdk/device/generic/rootfs_overlay/common/mnt/cfg/param/`

```bash
# 切换（或 deploy 后使用 /root/select_pq_bin.sh）
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin   # OV5647
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin      # GC2083
ls -la /mnt/cfg/param/cvi_sdr_bin
```

### RTSP

| 项目 | 值 |
|------|-----|
| 端口 | 8554 |
| 单摄 URL | `rtsp://192.168.42.1:8554/cam0`（建议 TCP：`:rtsp-tcp` / `-rtsp_transport tcp`） |
| 双摄 JSON | `cam_dual.json`（`cam0` / `cam1`，需 `dev_num=2`） |
| 日志 | `/tmp/rtsp_server.log` |

---

## 3. OV5647 黑屏根因（已解决）

**原因：** `sensor_cfg` 指向 OV5647，但 `cvi_sdr_bin` 软链仍指向 **GC2083** bin → ISP 调参错配。

早期日志：

```text
sensorName(0) mismatch, mwSns:22087 != pqBinSns:2053
```

**修复：** 切换 PQ bin 并干净重启 RTSP 后：

- 无 `mismatch`（或 sensorName 均为 22087）
- `OV5647 1080P 30fps ... Init OK`
- Mac 有画面，码率 ~**4.2 Mbps**（2026-06-05 实测）

**日常规则：** `sensor_cfg.ini` 与 `cvi_sdr_bin` 软链必须配对（见 §2）。`rtsp_preview_only.sh` / `select_pq_bin.sh` 会在部署后自动链 OV5647 bin。

---

## 4. 逐步确认清单（按顺序做，每项打勾）

后续会话可从上一次未完成项继续。状态列在文档中手动更新即可。

### 阶段 A — 硬件（已完成 ✅）

- [x] **A1** `i2cdetect -y 2` → `0x36`（J2 OV5647）
- [x] **A2** `i2cdetect -y 3` → `0x37`（J1 GC2083）
- [ ] **A3** Chip ID 读数与上表一致（可选复验）

### 阶段 B — GC2083 对照（验证 RTSP 链路，**已完成 ✅ 2026-06-05**）

目的：证明固件 + PQ bin + RTSP 正常，问题仅卡在 OV5647。

```bash
# 板上无 pkill 时用 stop_rtsp.sh 或 kill pid 文件
/root/stream/stop_rtsp.sh 2>/dev/null || kill "$(cat /tmp/rtsp_server.pid)" 2>/dev/null
sleep 2
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 12
grep -iE 'GC2083|Init OK|mismatch|sensorName' /tmp/rtsp_server.log | tail -15
```

- [x] **B1** RTSP 启动成功，GC2083 初始化正常
- [x] **B2** Mac `ffplay` / VLC：**有正常画面**（用户反馈略有延迟，见下）
- [x] **B3** 录 15s：`bit_rate=1768533`（~1.77 Mbps），1920×1080 @ ~30 fps — 非黑屏水平（对比 OV5647 ~25 kbps）

**结论：** RTSP 链路、固件、`cvi_sdr_bin_GC2083`、J1 接线均正常；OV5647 黑屏可排除「整机媒体栈坏了」。

### 阶段 C — OV5647 单摄（**已完成 ✅**，用户确认有画面）

```bash
/root/stream/stop_rtsp.sh 2>/dev/null || kill "$(cat /tmp/rtsp_server.pid)" 2>/dev/null
sleep 2
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 15
wc -l /tmp/rtsp_server.log
grep -iE 'mismatch|sensorName|22087|OV5647|Init OK' /tmp/rtsp_server.log
head -70 /tmp/rtsp_server.log    # PQ bin 块通常在日志前部，勿只看 tail
```

- [x] **C1** `sensor = OV_OV5647...`，`OV5647 1080P 30fps ... Init OK`，ISP/VPSS 正常
- [x] **C1b** 日志前部**无** `mismatch`（PQ bin 与 OV5647 匹配）
- [x] **C2** Mac 录 15s：`bit_rate=4181113`（~4.2 Mbps），31 fps
- [x] **C3** Mac 预览**有可见画面**（按 [SINGLE_CAM_BRINGUP.md](./SINGLE_CAM_BRINGUP.md) 步骤复现通过）

**根因收口：** `sensor_cfg_OV5647_J2.ini` + `cvi_sdr_bin_OV5647.bin`；日志可有 `pqbin md5 mismatch`（警告，不挡出图）。

**单摄调通配方（OV5647）：**

```bash
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
# 停 rtsp + rmmod debris 后
/root/stream/start_rtsp.sh /root/stream/cam0.json
```

### 阶段 D — PQ bin 资源（**已完成 ✅ 2026-06-05**）

```bash
ls -la /mnt/cfg/param/
/root/select_pq_bin.sh status    # deploy 后
```

- [x] **D1** 存在 `cvi_sdr_bin_OV5647.bin`（内含 sensor id **22087**）
- [x] **D2** 切换软链即可，无需重新生成 bin

```bash
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin   # OV5647 / J2
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin         # GC2083 / J1
kill "$(cat /tmp/rtsp_server.pid)"; rm -f /tmp/rtsp_server.pid
/root/stream/start_rtsp.sh /root/stream/cam0.json
```

### 阶段 E — debris 驱动（与 RTSP 独立，**按需**）

```bash
/root/reset_single_camera.sh
insmod /root/debris.ko i2c_sensor_mode=0    # 与 RTSP 共存时跳过 640×480
cat /proc/debris
/root/test_debris
```

- [ ] **E1** Chip ID、proc 节点正常（历史：`test_debris` 69 passed）

### 阶段 F — 混搭双摄 RTSP（**可试**，PQ bin 为难点）

**结论：可以同时用。** Duo S 硬件与 `rtsp_server` 支持 `dev_num=2`；本板 J1=GC2083、J2=OV5647 已写好混搭 ini。

| 路 | 座 | RTSP URL | sensor_cfg 段 |
|----|-----|----------|---------------|
| cam0 | J1 GC2083 | `rtsp://192.168.42.1:8554/cam0` | `[sensor]` |
| cam1 | J2 OV5647 | `rtsp://192.168.42.1:8554/cam1` | `[sensor2]` |

**文件（deploy 后）：**

- `stream/sensor_cfg_GC2083_OV5647_dual.ini`
- `stream/cam_dual.json` — **必须** `"dev-num": 2`（缺此项则只起一路 RTSP/VPSS，双摄无画面）
- `/root/setup_mixed_dual_camera.sh`、`/root/rtsp_dual_mixed.sh`

**常见无画面原因：** 旧版 `cam_dual.json` 未设 `dev-num:2`；`sensor_cfg` 里 `dev_num=2` 但 JSON 默认 `dev-num=1` → 管线半初始化。

```bash
/root/rtsp_dual_mixed.sh
# 或
/root/setup_mixed_dual_camera.sh
/root/stream/stop_rtsp.sh
/root/stream/start_rtsp.sh /root/stream/cam_dual.json
```

Mac 双路预览：

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam1
```

**PQ bin（关键）：** ISP 只加载**一个** `cvi_sdr_bin`，内需 **Sensor_0 + Sensor_1** 两路调参。板上现有的是单摄文件：

- `cvi_sdr_bin_GC2083` → 仅 GC2083 族
- `cvi_sdr_bin_OV5647.bin` → 仅 22087

| 软链目标 | 预期 |
|----------|------|
| `cvi_sdr_bin_GC2083` | cam0 正常，cam1 可能黑/偏色 |
| `cvi_sdr_bin_OV5647.bin` | cam1 正常，cam0 可能异常 |
| **PQ Tool 合并 bin** | 两路都正常（推荐长期方案） |

合并需 [Milk-V ISP PQ Tool / tuning 文档](https://milkv.io/docs/duo/camera/tuning)，或向 Milk-V 索要「GC2083+OV5647 双摄」`cvi_sdr_bin`。

**若暂不做合并 bin：** 用单摄切换仍最稳（`select_pq_bin.sh` + 对应 `sensor_cfg_*_J*.ini`）。

- [x] **F1** `sensor_cfg_GC2083_OV5647_dual.ini` 已提供
- [ ] **F2** 合并 PQ bin 或确认「单 bin 妥协」可接受
- [ ] **F3** cam0 + cam1 同时有画面

---

## 5. 单摄逐个调通（推荐顺序）

完整逐步说明（每条命令的作用）：**[SINGLE_CAM_BRINGUP.md](./SINGLE_CAM_BRINGUP.md)**

双摄失败后的 **唯一稳妥路径**：先 reboot，再**一次只测一颗**，通过后再测下一颗。

```bash
reboot
# 起来后 deploy 过则用：
chmod +x /root/test_single_cam.sh
```

### 步骤 1 — J1 GC2083

```bash
/root/test_single_cam.sh gc2083
```

| 检查项 | 通过标准 |
|--------|----------|
| 板上 | `GC2083 ... Init OK`，pid alive |
| mismatch | `2083 vs 2053` **可有**，阶段 B 已验证不影响 |
| Mac 码率 | ffprobe **~1–2 Mbps** |
| URL | `rtsp://192.168.42.1:8554/cam0` |

### 步骤 2 — J2 OV5647（仅步骤 1 Mac 有画面后再做）

```bash
# 必须先停掉上一路
/root/stream/stop_rtsp.sh 2>/dev/null || kill $(cat /tmp/rtsp_server.pid)
/root/test_single_cam.sh ov5647
```

| 检查项 | 通过标准 |
|--------|----------|
| PQ bin | `cvi_sdr_bin` → `cvi_sdr_bin_OV5647.bin` |
| 板上 | `OV5647 ... Init OK`，**无** mismatch |
| Mac 码率 | **~3–5 Mbps** |

### 手动等价命令（无 deploy 时）

```bash
# GC2083
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin

# OV5647
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin

# 共用：dev_num=1，cam0.json，停 rtsp + rmmod debris 后 start
```

**禁止**：单摄时使用 `dev_num=2` 的 ini 或 `cam_dual.json`。

---

## 6. 常用切换命令速查

```bash
# J2 OV5647（须同时切 PQ bin）
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin

# J1 GC2083
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin

# 或一条命令（deploy 后）
/root/select_pq_bin.sh ov5647   # 或 gc2083

# 恢复单摄 J2（若被 verify_board / dual 脚本改成 dev_num=2）
/root/reset_single_camera.sh

# RTSP 仅预览（不加载 debris）
/root/rtsp_preview_only.sh
```

---

## 7. RTSP 预览延迟（阶段 B 观察）

USB 网口 + RTSP 在 PC 上预览时，**1–3 秒体感延迟较常见**，不等于编码故障。可尝试：

```bash
# ffplay：减少缓冲（仍受 TCP/ISP 管线影响）
ffplay -rtsp_transport tcp -fflags nobuffer -flags low_delay -framedrop \
  rtsp://192.168.42.1:8554/cam0

# ffmpeg 拉流测试（看实时性，不录文件）
ffmpeg -rtsp_transport tcp -fflags nobuffer -flags low_delay \
  -i rtsp://192.168.42.1:8554/cam0 -f null -
```

若仅监控用途可接受；要低延迟需改 GOP、缓冲或走局域网千兆而非 USB RNDIS。阶段 B 码率 ~1.7 Mbps 说明画面内容正常。

---

## 8. 相关文档

- **[DEBUG_WORKFLOW.md](./DEBUG_WORKFLOW.md)** — Agent 协作交互规范 v2（先问→执行→分析）
- **[DEBUG_SESSION/INDEX.md](./DEBUG_SESSION/INDEX.md)** — **调试会话索引**（新对话必传）
- **[DEBUG_SESSION/DEBUG_SESSION_ISSUE001.md](./DEBUG_SESSION/DEBUG_SESSION_ISSUE001.md)** — 当前活跃 ISSUE
- [HARDWARE_NOTES.md](./HARDWARE_NOTES.md) — GPIO、I2C、Phase 4 编码计划
- [DEPLOYMENT.md](./DEPLOYMENT.md) — 编译部署与 PC 端 ffplay/ffmpeg
- [PROJECT_STATUS.md](./PROJECT_STATUS.md) — 驱动与测试用例进度
