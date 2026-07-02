# 双摄可用方案归档（ISSUE-002 收口）

> **归档日期：** 2026-07-01  
> **依据：** [DEBUG_SESSION_ISSUE002.md](./DEBUG_SESSION/DEBUG_SESSION_ISSUE002.md) Step 1–6  
> **硬件：** Milk-V Duo S · J1 GC2083（`i2c-3 / 0x37`）· J2 OV5647（`i2c-2 / 0x36`）

本文是 **当前板上已验证可出图** 的权威配方。形态三长期目标仍是统一 `8554/cam0`+`cam1`；在 GC2083 @ `rtsp_server` 修复前，**以本文为准**。

---

## 一览表


| 镜头            | 接口                             | 程序          | RTSP URL                        | 分辨率           | Mac 预览 |
| ------------- | ------------------------------ | ----------- | ------------------------------- | ------------- | ------ |
| **J1 GC2083** | `camera-test` / `sample_vi_fd` | 厂商 sample   | `rtsp://192.168.42.1:554/h264`  | **1280×720**  | ✅ 有画面  |
| **J2 OV5647** | `rtsp_server`                  | `cam0.json` | `rtsp://192.168.42.1:8554/cam0` | **1920×1080** | ✅ 有画面  |




### 明确不可用（勿再花时间）


| 场景                                                          | 结果                                |
| ----------------------------------------------------------- | --------------------------------- |
| GC2083 + `rtsp_server` + `8554/cam0`（含最小 json、PQ 显式、novpss） | ❌ Init OK，**无画面** / 空流            |
| GC2083 + `rtsp_server` + `554/stream0`                      | ❌ 无画面                             |
| **同时** `camera-test`(554) + `rtsp_server`(8554)             | ❌ MMF 互斥；554 refused、8554 VENC 失败 |
| 分时：先 GC2083@554 再 OV5647@8554                               | ✅ 各自可用，**不能同时** ffplay            |


---



## 通则（两路共用）

1. **单路预览**：一次只跑一路媒体进程；切换镜头前 **先停** 上一路。
2. `rmmod debris`：若加载过学习驱动，启动预览前执行（避免与厂商管线抢传感器）。
3. **ini 与 PQ 必须配对**（OV5647 错 bin 会黑屏；GC2083 的 `2083 vs 2053` mismatch 可忽略）。
4. Mac 建议 TCP：`ffplay -rtsp_transport tcp <url>`。



### 停干净旧进程（切换镜头前执行）

```bash
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
rmmod debris 2>/dev/null 
sleep 2
```

---



## J1 GC2083 — 已验证路径（554 / camera-test）



### 一键（deploy 后）

```bash
/root/preview_gc2083_554.sh
```

脚本会：停旧进程 → 链 GC2083 ini/PQ → 前台运行 `camera-test.sh`（**需保持终端，Ctrl+C 结束**）。

### 手动步骤

**板上（终端 A，保持运行）：**

```bash
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
rmmod debris 2>/dev/null

ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini

export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
sh /mnt/system/usr/bin/camera-test.sh
```

**Mac（camera-test 运行期间）：**

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:554/h264 -c copy -t 15 gc2083_554.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_554.mp4
```



### 通过标准


| 检查项      | 通过标准                                                      |
| -------- | --------------------------------------------------------- |
| 板上       | `sample_vi_fd` 进程存活；`netstat -ln                          |
| 日志       | `GCORE_GC2083...`、`GC2083 ... Init OK`                    |
| Mac      | `ffplay` **有画面**；`ffprobe` 约 **1280×720**，码率通常 ≥ 800 kb/s |
| mismatch | `2083 vs 2053` **可有**，不挡出图（见 CAMERA_VERIFY）               |




### 勿用

- `/root/stream/start_rtsp.sh` + `cam0.json` @ **8554**（ISSUE-002 已证黑流）
- `/root/rtsp_single_gc2083.sh` 旧版（曾走 8554；已改为调用本路径）

---



## J2 OV5647 — 已验证路径（8554 / rtsp_server）



### 一键（deploy 后）

```bash
/root/rtsp_single_ov5647.sh
```



### 手动步骤

**板上：**

```bash
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
rmmod debris 2>/dev/null

ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini

: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 20
netstat -ln | grep 8554
grep -iE 'OV5647|Init OK|mismatch' /tmp/rtsp_server.log | tail -10
```

**Mac：**

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 ov5647_8554.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 ov5647_8554.mp4
```



### 通过标准


| 检查项 | 通过标准                                                    |
| --- | ------------------------------------------------------- |
| 板上  | `rtsp_server` 存活；**8554** LISTEN                        |
| 日志  | `OV5647 ... Init OK`；**无** `22087 vs 2053` 类致命 mismatch |
| Mac | **有画面**；约 **1920×1080**，码率通常 ≥ 800 kb/s（常见 3–5 Mbps）    |




### PQ 注意

- 必须用 `cvi_sdr_bin_OV5647.bin`，**不能**链 `cvi_sdr_bin_GC2083`。

---



## 分时切换流程（两路都要测时）

```text
1. 停干净 → 2. GC2083 配方 + camera-test → Mac 测 554/h264 → Ctrl+C
3. 停干净 → 4. OV5647 配方 + start_rtsp.sh → Mac 测 8554/cam0
```

**不要**在 camera-test 仍运行时另开终端启 `rtsp_server`（Step 6 已证两路同时不可用）。

---



## 配置文件索引


| 用途                  | 路径                                                 |
| ------------------- | -------------------------------------------------- |
| GC2083 sensor ini   | `/mnt/data/sensor_cfg_GC2083.ini`                  |
| OV5647 sensor ini   | `/mnt/data/sensor_cfg_OV5647_J2.ini`               |
| 混搭双摄 ini（M2，未完全验证）  | `configs/sensor/sensor_cfg_GC2083_OV5647_dual.ini` |
| OV5647 单摄 RTSP json | `/root/stream/cam0.json`                           |
| 双摄 RTSP json        | `/root/stream/cam_dual.json`                       |


仓库权威副本：`edgeeye-duos/configs/stream/`、`configs/sensor/`。

---



## 根因摘要（供后续 ISSUE-003 / Milk-V）

- GC2083 在 `rtsp_server` **1080p** 链产出近黑 YUV；`sample_vi_fd` **720p** 缩放链正常。
- SG2000 MMF **不支持** `sample_vi` 与 `rtsp_server` 并行出流。
- 修复方向：Milk-V 官方 GC2083 rtsp json / 固件，或 SDK 为 `rtsp_server` 增加 720p 输出配置。

---



## 相关文档


| 文档                                                                     | 说明                         |
| ---------------------------------------------------------------------- | -------------------------- |
| [DEBUG_SESSION_ISSUE002.md](./DEBUG_SESSION/DEBUG_SESSION_ISSUE002.md) | 完整调试过程                     |
| [CAMERA_VERIFY.md](./CAMERA_VERIFY.md)                                 | 阶段 A–F 与 PQ 说明             |
| [PRODUCT_FORM3.md](./PRODUCT_FORM3.md)                                 | 形态三目标与过渡方案 §5              |
| [SINGLE_CAM_BRINGUP.md](./SINGLE_CAM_BRINGUP.md)                       | 逐步调通（GC2083 节请以 **本文** 为准） |


