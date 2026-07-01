# ISSUE-001: GC2083 单摄 Init OK 但 Mac ~25 kb/s 黑屏

**状态：** ✅ 已收口（8554 未修复；**554 workaround**；深挖转至 **ISSUE-002**）

---

## ISSUE-001 通用问答

**问题（用户填写）：**

```text
Step 6 完成后如何恢复 J1 GC2083 + J2 OV5647 双模组？
```

**Agent 解答：**

1. **接线：** GC2083 → **J1**（16P）；OV5647 → **J2**（15P 树莓派座）。
2. **OV5647 单摄 / 安全栈默认（8554）：**
   ```bash
   ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
   ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
   /root/stream/start_rtsp.sh /root/stream/cam0.json
   ```
   Mac：`rtsp://192.168.42.1:8554/cam0`（~4 Mbps，已验证）。
3. **GC2083 预览（8554 仍黑时）：**
   ```bash
   ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
   ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
   export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
   sh /mnt/system/usr/bin/camera-test.sh
   ```
   Mac：`rtsp://192.168.42.1:554/h264`（1280×720，**有画面**）。
4. 两路**不能**同时靠一个 `rtsp_server` 8554 解决 GC2083；双摄 RTSP 仍待 merged PQ bin + 混搭 ini（见 CAMERA_VERIFY 阶段 F）。

---

## 已知事实（Agent 维护）

- OV5647 单摄 ✅（~4 Mbps，`cvi_sdr_bin_OV5647.bin`）
- GC2083 软件：`sensor_cfg_GC2083.ini` + `cvi_sdr_bin_GC2083` ✅；`Init OK` ✅
- `2083 vs 2053` mismatch：阶段 B 有画面时也存在，暂不作为主因
- Step 1～4：配置正确；reboot/拔 J2 后仍 ~25 kb/s 空流
- Step 3：chip `0x2083`；ISP/VPSS 起；dmesg 无 MIPI error
- Step 4：**排除** J2 同插干扰
- Step 5：`camera-test` Init OK；Mac 误测 8554（`camera-test` 用 **554/h264**）→ 无效
- 冷启动 `i2cdetect` 无 0x37，VI 拉起后出现 → 常见 standby 行为

- Step 6.3：`554/h264` **有画面**（1280×720）
- Step 6续：`8554/cam0` Init OK，**bit_rate≈135473**，**无画面** → **554 有图 / 8554 黑** 已确认
- ~~模组 MIPI 全坏~~（554 有图已否定）

- Step 7A：reboot + `cam0.json` → **133790**，无画面
- Step 7B：首次 json 缺失；Step 8 补测 tuned json → **133783**，仍无画面
- **结论：** GC2083 硬件 OK；**554 有图**；**8554 rtsp_server 1080p 空流**（tuned json 无效）
- **8554 已排除：** PQ 链错、双摄干扰、冷启动、json 缺 buf/vi-vpss
- **未解：** 阶段 B 8554 曾 ~1.7 Mbps（Step 9B 后归档或开 ISSUE-002）

- Step 9B：抓帧成功；PNG **1920×1080、8KiB** → **近黑/均匀帧**；H.264 可解码 → **VENC 正常、YUV 输入近乎全黑**（非码流损坏）
- **ISSUE-001 收口：** 8554 软件对照已穷尽 Step 9；GC2083 请用 **554**；8554 深挖见 **ISSUE-002**

---

## 已完成步骤摘要


| Step                  | 结论                         |
| --------------------- | -------------------------- |
| 1 软件配置                | PQ/sensor_cfg 正确           |
| 2 reboot 复测           | 仍无画面                       |
| 3 诊断包                 | I2C/管线正常，25k               |
| 4 拔 J2 隔离             | 仍 25k，排除双摄干扰               |
| 5 J1 重插 + camera-test | Init OK；Mac 误测 8554 |
| 6 补测 | 554 有画面 |
| 6续 | 8554 Init OK，135k，无画面 |
| 7 | 7A 133k；7B 首次未测 |
| 8 tuned json | 仍 133k，无画面 |
| 9A vi-vpss-mode 0 | ❌ ~18k，无画面 |
| 9B 抓帧诊断 | ✅ 近黑帧 8KiB |


> Step 1～5 详细日志见 git 历史中的 `DEBUG_SESSION.md`（已归档指向本目录）。

---

## Step 6 — 补测：camera-test 正确 URL + rtsp_server 对照 ✅ 部分完成（6.4/6.5 见 Step 6续）

**目的：** 在 `camera-test` 正确 RTSP 地址上验证画面；再与 `8554/cam0` 对照，区分模组问题 vs `rtsp_server` 路径问题。

#### 执行前问答

**状态：** ✅ 可以执行了

**问题（用户填写）：**

```text
（可选）
```

**Agent 解答：**

```text
通过标准已填写。camera-test 会阻塞运行属正常；Mac 须在 camera-test 未 Ctrl+C 时测 554/h264。
```

**通过标准：**

1. **6.2** `netstat` 在 `camera-test` 运行期间能看到 RTSP 监听端口（通常 **554**）。
2. **6.3** `ffprobe` 对 `rtsp://192.168.42.1:554/h264`：`bit_rate` ≥ **800000**，且肉眼有画面；或明确记录 `连接失败`（按 §5.3 异常格式）。
3. **6.4** `start_rtsp.sh` 后 `8554` 监听，日志含 `GC2083` + `Init OK`。
4. **6.5** `ffprobe` 对 `8554/cam0`：`bit_rate` ≥ **800000**，且肉眼有画面。
5. **满足 2 或 4 任一** 即本步 **通过**；二者均 ~25k 且无画面 → **未通过**。

**板上 / Mac 命令：**

**6.1 终端 A（保持运行，勿立刻 Ctrl+C）**

```bash
rmmod debris 2>/dev/null
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
sh /mnt/system/usr/bin/camera-test.sh
```

**6.2 终端 B（camera-test 仍在跑）**

```bash
netstat -ln | grep -E '554|8554|rtsp'
```

**6.3 Mac（camera-test 运行期间）**

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:554/h264 -c copy -t 15 gc2083_cameratest.mp4
ffprobe -show_entries stream=bit_rate -of default=nw=1 gc2083_cameratest.mp4
```

**6.4 终端 A Ctrl+C 后**

```bash
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 25
netstat -ln | grep 8554
grep -iE 'GC2083|Init OK' /tmp/rtsp_server.log | tail -5
```

**6.5 Mac（rtsp_server）**

```bash
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step6.mp4
ffprobe -show_entries stream=bit_rate -of default=nw=1 gc2083_step6.mp4
```

**结果（用户填写）：**

```shell
# === 操作确认 ===
[root@milkv-duo]~# rmmod debris 2>/dev/null
[root@milkv-duo]~# ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_
cfg.ini
[root@milkv-duo]~# ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
[root@milkv-duo]~# export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/l
ib:/mnt/system/usr/lib/3rd
[root@milkv-duo]~# sh /mnt/system/usr/bin/camera-test.sh
[SAMPLE_COMM_SNS_ParseIni]-2219: Parse /mnt/data/sensor_cfg.ini
[parse_source_devnum]-1812: devNum =  1
[parse_sensor_name]-1893: sensor =  GCORE_GC2083_MIPI_2M_30FPS_10BIT
[parse_sensor_busid]-1922: bus_id =  3
[parse_sensor_i2caddr]-1933: sns_i2c_addr =  37
[parse_sensor_mipidev]-1944: mipi_dev =  0
[parse_sensor_laneid]-1955: Lane_id =  2, 0, 1, -1, -1
[parse_sensor_pnswap]-1966: pn_swap =  0, 0, 0,  0,  0
MMF Version:6b03c2762-64bit
Create VBPool[0], size: (3110400 * 5) = 15552000 bytes
Create VBPool[1], size: (1382400 * 5) = 6912000 bytes
Create VBPool[2], size: (2764800 * 3) = 8294400 bytes
Total memory of VB pool: 30758400 bytes
Initialize SYS and VB
Initialize VI
ISP Vipipe(0) Allocate pa(0x97156000) va(0x0x3fcd9ac000) size(311584)
stSnsrMode.u16Width 1920 stSnsrMode.u16Height 1080 30.000000 wdrMode 0 pstSnsObj 0x3fce4633e8
[SAMPLE_COMM_VI_StartMIPI]-494: sensor 0 stDevAttr.devno 0
awbInit ver 6.9@2021500
0 R:1400 B:3100 CT:2850
1 R:1500 B:2500 CT:3900
2 R:2300 B:1600 CT:6500
Golden 1024 1024 1024
WB Quadratic:0
isWdr:0
ViPipe:0,===GC2083 1080P 30fps 10bit LINE Init OK!===
********************************************************************************
cvi_bin_isp message
gerritId:      NULL           commitId:      6b03c2762
md5:           1b6dd6bec5dfd417b8d1136b9ca0aa67
sensorNum      1
sensorName0    2083

PQBIN message
gerritId:      80171          commitId:      5c9d8fc5d
md5:           ba5a510e093ad42db6788e6c2d13169e
sensorNum      3
sensorName0    2053

author:        wanqiang.he    desc:          思博慧CV1812H_GC2083_RGB_mode_V1.0.0
createTime:    2023-08-04 16:48:08version:       V1.1
tool Version:       v3.0.5.24           mode:
********************************************************************************
sensorName(0) mismatch, mwSns:2083 != pqBinSns:2053
19700101 00:17:51.736 2442 E isp AF_GetAttr:574 pstFocusMpiAttr is NULL
JSON_READ_ERR:NOT_EXIST 71(L) lblc

JSON_READ_ERR:NOT_EXIST 71(L) lblcLut

JSON_READ_ERR:NOT_EXIST 71(L) clut_hsl

JSON_READ_ERR:DATA_TYPE 77(L) vc_motion.MotionThreshold

JSON_READ_ERR:NOT_EXIST 71(L) teaisp_bnr

JSON_READ_ERR:NOT_EXIST 71(L) teaisp_bnr_np

JSON_READ_ERR:NOT_EXIST 71(L) AWBAttrEx.u16MultiLSThr

JSON_READ_ERR:NOT_EXIST 71(L) AWBAttrEx.u16CALumaDiff

JSON_READ_ERR:NOT_EXIST 71(L) AWBAttrEx.u16CAAdjustRatio

JSON_READ_ERR:NOT_EXIST 71(L) AWBAttrEx.stInterference

JSON_READ_ERR:NOT_EXIST 71(L) FocusAttr

19700101 00:17:52.419 2442 E isp AF_SetAttr:558 pstFocusMpiAttr is NULL
[SAMPLE_COMM_ISP_Thread]-390: ISP Dev 0 running!
Initialize VPSS
---------VPSS[0]---------
Input size: (1920x1080)
Input format: (19)
VPSS physical device number: 1
Src Frame Rate: -1
Dst Frame Rate: -1
    --------CHN[0]-------
    Output size: (1280x720)
    Depth: 1
    Do normalization: 0
        Src Frame Rate: -1
        Dst Frame Rate: -1
    ----------------------
    --------CHN[1]-------
    Output size: (1280x720)
    Depth: 1
    Do normalization: 0
        Src Frame Rate: -1
        Dst Frame Rate: -1
    ----------------------
------------------------
Bind VI with VPSS Grp(0), Chn(0)
Attach VBPool(0) to VPSS Grp(0) Chn(0)
Attach VBPool(1) to VPSS Grp(0) Chn(1)
Initialize VENC
venc codec: h264
venc frame size: 1280x720
Initialize RTSP
rtsp://169.254.103.201/h264
prio:0
anchor:-8,-8,8,8
anchor:-16,-16,16,16
bbox:bbox_8_Conv_dequant
landmark:kps_8_Conv_dequant
score:score_8_Sigmoid_dequant
anchor:-32,-32,32,32
anchor:-64,-64,64,64
bbox:bbox_16_Conv_dequant
landmark:kps_16_Conv_dequant
score:score_16_Sigmoid_dequant
anchor:-128,-128,128,128
anchor:-256,-256,256,256
bbox:bbox_32_Conv_dequant
landmark:kps_32_Conv_dequant
score:score_32_Sigmoid_dequant
Enter TDL thread
Enter encoder thread
0 R:1165 B:3087 CT:2688
1 R:1464 B:2327 CT:3937
2 R:1974 B:1613 CT:7225
Golden 1464 1024 2327
wdrLEOnly:1
# === 6.2 netstat ===
[root@milkv-duo]~# netstat -ln | grep -E '554|8554|rtsp'
tcp        0      0 0.0.0.0:554             0.0.0.0:*               LISTEN

# === 6.3 camera-test（ffprobe + 画面）===
~> ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:554/h264 -c copy -t 15 gc2083_cameratest.mp4
ffprobe -show_entries stream=bit_rate -of default=nw=1 gc2083_cameratest.mp4
ffplay version 8.1.1 Copyright (c) 2003-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
[h264 @ 0x94ef21880] non-existing PPS 0 referencedsq=    0B
    Last message repeated 1 times
[h264 @ 0x94ef21880] no frame!
Input #0, rtsp, from 'rtsp://192.168.42.1:554/h264':
  Metadata:
    title           :
    comment         : h264
  Duration: N/A, start: 0.034456, bitrate: N/A
  Stream #0:0: Video: h264 (Constrained Baseline), yuv420p(progressive), 1280x720, 30 fps, 30 tbr, 90k tbn, start 0.034456
  29.42 M-V:  0.005 fd=  10 aq=    0KB vq=  331KB sq=    0B
有画面

# === 6.4 rtsp_server grep + netstat ===


# === 6.5 8554（ffprobe + 画面）===

# === 结论 ===
部分完成：6.3 有画面；6.4/6.5 未执行；整体未通过
```

**Agent 分析：**

- **6.1～6.2 ✅：** `camera-test` Init OK；`0.0.0.0:554` LISTEN。
- **6.3 ✅（画面）：** `ffplay rtsp://192.168.42.1:554/h264` 连接成功，流为 **1280×720@30**；你确认 **有画面**。开头 `non-existing PPS` / `no frame` 多为入流未遇 I-帧时的解码器警告，可忽略。
- **6.3 码率：** 未贴 `ffprobe` 对 `gc2083_cameratest.mp4` 的输出，通过标准第 2 条码率项**未记录**。
- **6.4/6.5 ❌ 缺失：** 未测 `8554/cam0`，无法判断 `rtsp_server` 是否仍 ~25k。
- **根因转向：** GC2083 **能出图**（原厂 `sample_vi_fd` 路径）。此前 ~25k 黑屏更可能来自 **`rtsp_server` 配置/启动方式**，或 **`sample_vi` 与 `rtsp_server` 争用 VI**（须先干净退出 camera-test 再起 8554）。
- **本步判定：** **部分完成 / 整体未通过**（按通过标准需补 6.4/6.5）。
- **下一步：** Step 6续 — 仅补 6.4 + 6.5。

---

## Step 6续 — 仅补 rtsp_server 8554 对照 ✅ 已完成（未通过）

**目的：** 在已证实 GC2083 能出图的前提下，确认 `rtsp_server` `8554/cam0` 是否仍黑屏。

#### 执行前问答

**状态：** ✅ 可以执行了

**问题（用户填写）：**

```text
（可选）
```

**Agent 解答：**

```text
须先彻底结束 camera-test（Ctrl+C），并 kill 残留 sample_vi 进程，再 start_rtsp.sh。
```

**通过标准：**

1. **6.4** `netstat` 见 `8554` LISTEN；`/tmp/rtsp_server.log` 含 `GC2083` + `Init OK`。
2. **6.5** `ffprobe` 对 `8554/cam0`：`bit_rate` ≥ **800000**，且肉眼有画面 → **本步通过**。
3. 若 `bit_rate` 仍 ~25k 且无画面 → **未通过**，进入 Step 7（查 `cam0.json` / `rtsp_server` 与原厂差异）。

```shell
# --- 命令：板上（camera-test 已 Ctrl+C）---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 3
rmmod debris 2>/dev/null
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 25
netstat -ln | grep 8554
grep -iE 'GC2083|Init OK|fail|error' /tmp/rtsp_server.log | tail -8

# --- 结果：板上（粘贴在上方命令下方）---
[root@milkv-duo]~# for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}
'); do kill $_p; done
[root@milkv-duo]~# rm -f /tmp/rtsp_server.pid
[root@milkv-duo]~# sleep 3
[root@milkv-duo]~# rmmod debris 2>/dev/null
[root@milkv-duo]~# ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
[root@milkv-duo]~# ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
[root@milkv-duo]~# : > /tmp/rtsp_server.log
[root@milkv-duo]~# /root/stream/start_rtsp.sh /root/stream/cam0.json
rtsp_server started pid 3749
log: /tmp/rtsp_server.log
preview: ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
dual config uses cam0 + cam1 when sensor_cfg dev_num=2
[root@milkv-duo]~# sleep 25
[root@milkv-duo]~# netstat -ln | grep 8554
tcp        0      0 0.0.0.0:8554            0.0.0.0:*               LISTEN
[root@milkv-duo]~# grep -iE 'GC2083|Init OK|fail|error' /tmp/rtsp_server.log | tail -8
[parse_sensor_name]-1893: sensor =  GCORE_GC2083_MIPI_2M_30FPS_10BIT
ViPipe:0,===GC2083 1080P 30fps 10bit LINE Init OK!===
author:        wanqiang.he    desc:          思博慧CV1812H_GC2083_RGB_mode_V1.0.0

# --- 命令：Mac ---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step6b.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step6b.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果：Mac ---
!leading ~/Documents/learn/riscv/Camera> ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step6b.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step6b.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, rtsp, from 'rtsp://192.168.42.1:8554/cam0':
  Metadata:
    title           :
    comment         : cam0
  Duration: N/A, start: 0.033256, bitrate: N/A
  Stream #0:0: Video: h264 (High), yuv420p(progressive), 1920x1080, 30 tbr, 90k tbn, start 0.033256
Stream mapping:
  Stream #0:0 -> #0:0 (copy)
Output #0, mp4, to 'gc2083_step6b.mp4':
  Metadata:
    title           :
    comment         : cam0
    encoder         : Lavf62.12.101
  Stream #0:0: Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, q=2-31, 30 tbr, 90k tbn
Press [q] to stop, [?] for help
[mp4 @ 0xb16c1c280] Timestamps are unset in a packet for stream 0. This is deprecated and will stop working in the future. Fix your code to set the timestamps properly
[vost#0:0/copy @ 0xb16c50300] Non-monotonic DTS; previous: 0, current: 0; changing to 1. This may result in incorrect timestamps in the output file.
frame=   43 fps=0.0 q=-1.0 size=       0KiB time=00:00:01.39 bitrate=   0.3kbits/s speed=frame=   58 fps= 58 q=-1.0 size=       0KiB time=00:00:01.89 bitrate=   0.2kbits/s speed=frame=   73 fps= 48 q=-1.0 size=       0KiB time=00:00:02.39 bitrate=   0.2kbits/s speed=frame=   88 fps= 44 q=-1.0 size=       0KiB time=00:00:02.89 bitrate=   0.1kbits/s speed=frame=  103 fps= 41 q=-1.0 size=       0KiB time=00:00:03.39 bitrate=   0.1kbits/s speed=frame=  118 fps= 39 q=-1.0 size=       0KiB time=00:00:03.89 bitrate=   0.1kbits/s speed=frame=  133 fps= 38 q=-1.0 size=       0KiB time=00:00:04.39 bitrate=   0.1kbits/s speed=frame=  148 fps= 37 q=-1.0 size=       0KiB time=00:00:04.89 bitrate=   0.1kbits/s speed=frame=  163 fps= 36 q=-1.0 size=       0KiB time=00:00:05.39 bitrate=   0.1kbits/s speed=frame=  178 fps= 35 q=-1.0 size=       0KiB time=00:00:05.89 bitrate=   0.1kbits/s speed=frame=  193 fps= 35 q=-1.0 size=       0KiB time=00:00:06.39 bitrate=   0.1kbits/s speed=frame=  209 fps= 35 q=-1.0 size=       0KiB time=00:00:06.93 bitrate=   0.1kbits/s speed=frame=  224 fps= 34 q=-1.0 size=       0KiB time=00:00:07.43 bitrate=   0.1kbits/s speed=frame=  239 fps= 34 q=-1.0 size=       0KiB time=00:00:07.93 bitrate=   0.0kbits/s speed=frame=  254 fps= 34 q=-1.0 size=       0KiB time=00:00:08.43 bitrate=   0.0kbits/s speed=frame=  269 fps= 33 q=-1.0 size=       0KiB time=00:00:08.92 bitrate=   0.0kbits/s speed=frame=  284 fps= 33 q=-1.0 size=       0KiB time=00:00:09.42 bitrate=   0.0kbits/s speed=frame=  299 fps= 33 q=-1.0 size=       0KiB time=00:00:09.92 bitrate=   0.0kbits/s speed=frame=  314 fps= 33 q=-1.0 size=       0KiB time=00:00:10.42 bitrate=   0.0kbits/s speed=frame=  329 fps= 33 q=-1.0 size=       0KiB time=00:00:10.92 bitrate=   0.0kbits/s speed=frame=  344 fps= 33 q=-1.0 size=       0KiB time=00:00:11.42 bitrate=   0.0kbits/s speed=frame=  359 fps= 32 q=-1.0 size=       0KiB time=00:00:11.92 bitrate=   0.0kbits/s speed=frame=  374 fps= 32 q=-1.0 size=       0KiB time=00:00:12.42 bitrate=   0.0kbits/s speed=frame=  389 fps= 32 q=-1.0 size=       0KiB time=00:00:12.92 bitrate=   0.0kbits/s speed=frame=  404 fps= 32 q=-1.0 size=       0KiB time=00:00:13.42 bitrate=   0.0kbits/s speed=frame=  420 fps= 32 q=-1.0 size=       0KiB time=00:00:13.96 bitrate=   0.0kbits/s speed=frame=  435 fps= 32 q=-1.0 size=       0KiB time=00:00:14.46 bitrate=   0.0kbits/s speed=frame=  450 fps= 32 q=-1.0 size=       0KiB time=00:00:14.96 bitrate=   0.0kbits/s speed=[out#0/mp4 @ 0xb16c4c240] video:249KiB audio:0KiB subtitle:0KiB other streams:0KiB global headers:0KiB muxing overhead: 2.450745%
frame=  452 fps= 32 q=-1.0 Lsize=     255KiB time=00:00:15.06 bitrate= 138.5kbits/s speed=1.06x elapsed=0:00:14.19
ffprobe version 8.1.1 Copyright (c) 2007-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'gc2083_step6b.mp4':
  Metadata:
    major_brand     : isom
    minor_version   : 512
    compatible_brands: isomiso2avc1mp41
    encoder         : Lavf62.12.101
    comment         : cam0
  Duration: 00:00:15.03, start: 0.000000, bitrate: 138 kb/s
  Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, 135 kb/s, 30.08 fps, 30 tbr, 90k tbn (default)
    Metadata:
      handler_name    : VideoHandler
width=1920
height=1080
bit_rate=135473
ffplay version 8.1.1 Copyright (c) 2003-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, rtsp, from 'rtsp://192.168.42.1:8554/cam0':
  Metadata:
    title           :
    comment         : cam0
  Duration: N/A, start: 0.033100, bitrate: N/A
  Stream #0:0: Video: h264 (High), yuv420p(progressive), 1920x1080, 30 tbr, 90k tbn, start 0.033100
  23.29 M-V:  0.020 fd=  10 aq=    0KB vq=    5KB sq=    0B

# --- 结论 ---
未通过，没有视频画面
```

**Agent 分析：**

- **6.4 ✅：** `8554` LISTEN；`GC2083 Init OK`。
- **6.5 ❌：** `bit_rate=135473`（~135 kb/s），远低于通过线 **800000**；你确认 **无画面**。较早期 ~25k 略高，但仍属空流/极低信息帧。
- **对照 Step 6.3：** 同一 J1、同一 session 内，`camera-test` **554 有图**，`rtsp_server` **8554 无图** → 根因收敛到 **`rtsp_server` 路径 / `cam0.json` 配置**，非 GC2083 模组不可用。
- **参考：** 阶段 B 曾用 `8554/cam0` ~1.7 Mbps，说明该路径**曾经可用**；当前需排查 json 缺项（如 `buf-blk-cnt`、`vi-vpss-mode`）或冷启动顺序。
- **本步判定：** **未通过**。
- **下一步：** Step 7 — reboot 后冷启动 rtsp，再试 tuned json。

---

## Step 7 — rtsp_server 8554 修复验证 ✅ 已完成（未通过；7B 未有效执行）

**目的：** 在已确认 554 有图的前提下，让 `8554/cam0` 恢复可出图。分 **7A 冷启动**、**7B tuned json**（7A 未通过再做 7B）。

#### 执行前问答

**状态：** ✅ 可以执行了

**问题（用户填写）：**

```text
（可选）
```

**Agent 解答：**

```text
7A 与 7B 在同一次 reboot 后顺序做：先 7A（cam0.json），未通过再 7B（cam0_gc2083_tuned.json，deploy 后位于 /root/stream/）。
全程不要再跑 camera-test，避免 VI 占用干扰对照。
```

**通过标准：**

1. `8554` LISTEN，日志 `GC2083` + `Init OK`。
2. Mac `ffprobe`：`bit_rate` ≥ **800000**，且肉眼有画面 → **本步通过**。
3. 7A 未通过时可继续 7B；7B 仍不满足 2 → **未通过**，ISSUE 暂挂并记录 workaround（554/h264）。

```shell
# --- 命令：7A 冷启动（reboot 后，勿跑 camera-test）---
reboot
# SSH 登录后：
rmmod debris 2>/dev/null
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 25
grep -iE 'GC2083|Init OK|VPSS|fail|error' /tmp/rtsp_server.log | tail -12

# --- 结果：7A 板上 ---
[root@milkv-duo]~# rmmod debris 2>/dev/null
[root@milkv-duo]~# ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
[root@milkv-duo]~# ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
[root@milkv-duo]~# for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}
'); do kill $_p; done
[root@milkv-duo]~# rm -f /tmp/rtsp_server.pid
[root@milkv-duo]~# : > /tmp/rtsp_server.log
[root@milkv-duo]~# /root/stream/start_rtsp.sh /root/stream/cam0.json
rtsp_server started pid 406
log: /tmp/rtsp_server.log
preview: ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
dual config uses cam0 + cam1 when sensor_cfg dev_num=2
[root@milkv-duo]~# sleep 25
[root@milkv-duo]~# grep -iE 'GC2083|Init OK|VPSS|fail|error' /tmp/rtsp_server.log | tail -12
video-src-info : [{"codec":"264","rtsp-url":"cam","venc-bind-vpss":true}]
[parse_sensor_name]-1893: sensor =  GCORE_GC2083_MIPI_2M_30FPS_10BIT
*** vi_vpss_mode:1
**** - bVpssBinding:1
**** - VpssChn:0
**** - bVencBindVpss:1
ViPipe:0,===GC2083 1080P 30fps 10bit LINE Init OK!===
author:        wanqiang.he    desc:          思博慧CV1812H_GC2083_RGB_mode_V1.0.0
VpssChn0 , Enable Vpss Grp: 0
VPSS init with src (1920, 1080) dst (1920, 1080).
CVI_VPSS_CreateGrp:0, s32Ret=0

# --- 命令：7A Mac ---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step7a.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step7a.mp4

# --- 结果：7A Mac ---
!?leading ~/Documents/learn/riscv/Camera> ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step7a.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step7a.mp4
ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, rtsp, from 'rtsp://192.168.42.1:8554/cam0':
  Metadata:
    title           :
    comment         : cam0
  Duration: N/A, start: 0.040911, bitrate: N/A
  Stream #0:0: Video: h264 (High), yuv420p(progressive), 1920x1080, 30 fps, 30 tbr, 90k tbn, start 0.040911
Stream mapping:
  Stream #0:0 -> #0:0 (copy)
Output #0, mp4, to 'gc2083_step7a.mp4':
  Metadata:
    title           :
    comment         : cam0
    encoder         : Lavf62.12.101
  Stream #0:0: Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, q=2-31, 30 fps, 30 tbr, 90k tbn
Press [q] to stop, [?] for help
[mp4 @ 0xb22c1c280] Timestamps are unset in a packet for stream 0. This is deprecated and will stop working in the future. Fix your code to set the timestamps properly
[vost#0:0/copy @ 0xb22c44300] Non-monotonic DTS; previous: 0, current: 0; changing to 1. This may result in incorrect timestamps in the output file.
frame=   43 fps=0.0 q=-1.0 size=       0KiB time=00:00:01.39 bitrate=   0.3kbits/s speed=frame=   58 fps= 58 q=-1.0 size=       0KiB time=00:00:01.89 bitrate=   0.2kbits/s speed=frame=   73 fps= 48 q=-1.0 size=       0KiB time=00:00:02.39 bitrate=   0.2kbits/s speed=frame=   88 fps= 44 q=-1.0 size=       0KiB time=00:00:02.89 bitrate=   0.1kbits/s speed=frame=  103 fps= 41 q=-1.0 size=       0KiB time=00:00:03.39 bitrate=   0.1kbits/s speed=frame=  118 fps= 39 q=-1.0 size=       0KiB time=00:00:03.89 bitrate=   0.1kbits/s speed=frame=  133 fps= 38 q=-1.0 size=       0KiB time=00:00:04.39 bitrate=   0.1kbits/s speed=frame=  149 fps= 37 q=-1.0 size=       0KiB time=00:00:04.92 bitrate=   0.1kbits/s speed=frame=  164 fps= 36 q=-1.0 size=       0KiB time=00:00:05.42 bitrate=   0.1kbits/s speed=frame=  179 fps= 36 q=-1.0 size=       0KiB time=00:00:05.92 bitrate=   0.1kbits/s speed=frame=  194 fps= 35 q=-1.0 size=       0KiB time=00:00:06.42 bitrate=   0.1kbits/s speed=frame=  209 fps= 35 q=-1.0 size=       0KiB time=00:00:06.92 bitrate=   0.1kbits/s speed=frame=  224 fps= 34 q=-1.0 size=       0KiB time=00:00:07.42 bitrate=   0.1kbits/s speed=frame=  239 fps= 34 q=-1.0 size=       0KiB time=00:00:07.92 bitrate=   0.0kbits/s speed=frame=  254 fps= 34 q=-1.0 size=       0KiB time=00:00:08.42 bitrate=   0.0kbits/s speed=frame=  269 fps= 33 q=-1.0 size=       0KiB time=00:00:08.92 bitrate=   0.0kbits/s speed=frame=  284 fps= 33 q=-1.0 size=       0KiB time=00:00:09.42 bitrate=   0.0kbits/s speed=frame=  299 fps= 33 q=-1.0 size=       0KiB time=00:00:09.92 bitrate=   0.0kbits/s speed=frame=  315 fps= 33 q=-1.0 size=       0KiB time=00:00:10.46 bitrate=   0.0kbits/s speed=frame=  330 fps= 33 q=-1.0 size=       0KiB time=00:00:10.96 bitrate=   0.0kbits/s speed=frame=  345 fps= 33 q=-1.0 size=       0KiB time=00:00:11.46 bitrate=   0.0kbits/s speed=frame=  360 fps= 33 q=-1.0 size=       0KiB time=00:00:11.96 bitrate=   0.0kbits/s speed=frame=  375 fps= 32 q=-1.0 size=       0KiB time=00:00:12.46 bitrate=   0.0kbits/s speed=frame=  390 fps= 32 q=-1.0 size=       0KiB time=00:00:12.96 bitrate=   0.0kbits/s speed=frame=  405 fps= 32 q=-1.0 size=       0KiB time=00:00:13.46 bitrate=   0.0kbits/s speed=frame=  420 fps= 32 q=-1.0 size=       0KiB time=00:00:13.96 bitrate=   0.0kbits/s speed=frame=  435 fps= 32 q=-1.0 size=       0KiB time=00:00:14.46 bitrate=   0.0kbits/s speed=frame=  450 fps= 32 q=-1.0 size=       0KiB time=00:00:14.96 bitrate=   0.0kbits/s speed=[out#0/mp4 @ 0xb23004780] video:245KiB audio:0KiB subtitle:0KiB other streams:0KiB global headers:0KiB muxing overhead: 2.469072%
frame=  452 fps= 32 q=-1.0 Lsize=     251KiB time=00:00:15.05 bitrate= 136.8kbits/s speed=1.06x elapsed=0:00:14.19
ffprobe version 8.1.1 Copyright (c) 2007-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'gc2083_step7a.mp4':
  Metadata:
    major_brand     : isom
    minor_version   : 512
    compatible_brands: isomiso2avc1mp41
    encoder         : Lavf62.12.101
    comment         : cam0
  Duration: 00:00:15.03, start: 0.000000, bitrate: 137 kb/s
  Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, 133 kb/s, 30.08 fps, 30 tbr, 90k tbn (default)
    Metadata:
      handler_name    : VideoHandler
width=1920
height=1080
bit_rate=133790
画面什么都没有

# --- 命令：7B（仅 7A 未通过时）---
for _p in $(ps | grep rtsp_server | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0_gc2083_tuned.json
sleep 25
grep -iE 'GC2083|Init OK|VPSS|dev_num|vi_vpss' /tmp/rtsp_server.log | tail -12

# --- 结果：7B 板上 ---
[root@milkv-duo]~# for _p in $(ps | grep rtsp_server | grep -v grep | awk '{print $1}'); do kill $_p
; done
[root@milkv-duo]~# rm -f /tmp/rtsp_server.pid
[root@milkv-duo]~# : > /tmp/rtsp_server.log
[root@milkv-duo]~# /root/stream/start_rtsp.sh /root/stream/cam0_gc2083_tuned.json
start_rtsp: missing config /root/stream/cam0_gc2083_tuned.json
[root@milkv-duo]~# sleep 25
[root@milkv-duo]~# grep -iE 'GC2083|Init OK|VPSS|dev_num|vi_vpss' /tmp/rtsp_server.log | tail -12
[root@milkv-duo]~#

# --- 命令：7B Mac ---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step7b.mp4
ffprobe -show_entries stream=bit_rate -of default=nw=1 gc2083_step7b.mp4

# --- 结果：7B Mac ---
!?leading ~/Documents/learn/riscv/Camera> ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step7b.mp4
ffprobe -show_entries stream=bit_rate -of default=nw=1 gc2083_step7b.mp4
ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
[tcp @ 0x885064000] Connection to tcp://192.168.42.1:8554?timeout=0 failed: Connection refused
[in#0 @ 0x885020000] Error opening input: Connection refused
Error opening input file rtsp://192.168.42.1:8554/cam0.
Error opening input files: Connection refused
ffprobe version 8.1.1 Copyright (c) 2007-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
gc2083_step7b.mp4: No such file or directory

# --- 结论 ---
均未通过
```

**Agent 分析：**

- **7A ❌：** reboot 后**仅** `cam0.json` + `rtsp_server`；Init OK、VPSS 1920×1080 正常；Mac **bit_rate=133790**、**无画面**。与 Step 6续 几乎相同 → **冷启动不能恢复 8554**；问题稳定在 `rtsp_server` 1080p 路径，非 camera-test 残留状态。
- **7B ⚠️ 无效：** 板上无 `/root/stream/cam0_gc2083_tuned.json`（未 deploy）；`start_rtsp` 直接失败；Mac `Connection refused` 是 7B 未起服务导致，**不能**当作 tuned json 测试结果。
- **对照不变：** Step 6 已证 `554/h264`（`sample_vi_fd`）**有画面**；8554 持续 ~130k 空流。
- 本步判定： **均未通过**（7B 待 Step 8 补测）。
- **下一步：** Step 8 — 在板上**写入** tuned json 后重测 7B；仍失败则记录 554 workaround + 查原厂最小 json。

---

## Step 8 — 补测 7B（板上创建 tuned json）✅ 已完成（未通过）

**目的：** 完成 Step 7 未执行的 7B；`cam0_gc2083_tuned.json` 含 `vi-vpss-mode`、`buf-blk-cnt`、`compress-mode`（与 `cam_dual.json` 对齐）。

#### 执行前问答

**状态：** ✅ 可以执行了

**问题（用户填写）：**

```text
（可选）
```

**Agent 解答：**

```text
无需 deploy：Step 8 用 cat 在板上直接创建 json。仍勿跑 camera-test。
```

**通过标准：**

1. `start_rtsp.sh ... cam0_gc2083_tuned.json` 成功，日志 `GC2083` + `Init OK`。
2. Mac `ffprobe`：`bit_rate` ≥ **800000** 且有画面 → **通过**。
3. 仍 ~130k 且无画面 → **未通过**，ISSUE 收口为「8554 暂不可用，554 workaround」。

```shell
# --- 命令：板上创建 json 并启动 ---
cat > /root/stream/cam0_gc2083_tuned.json << 'EOF'
{
    "rtsp-port": 8554,
    "vi-vpss-mode": 1,
    "buf1-blk-cnt": 4,
    "sensor-config-path": "/mnt/data/sensor_cfg.ini",
    "video-src-info": [{
        "chn": 0,
        "rtsp-url": "cam",
        "buf-blk-cnt": 4,
        "codec": "264",
        "venc-bind-vpss": true,
        "compress-mode": "tile"
    }]
}
EOF

rmmod debris 2>/dev/null
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0_gc2083_tuned.json
sleep 25
grep -iE 'GC2083|Init OK|VPSS|vi_vpss|fail|error' /tmp/rtsp_server.log | tail -15

# --- 结果：板上 ---
[root@milkv-duo]~# rmmod debris 2>/dev/null
[root@milkv-duo]~# ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
[root@milkv-duo]~# ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
[root@milkv-duo]~# for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}
'); do kill $_p; done
[root@milkv-duo]~# rm -f /tmp/rtsp_server.pid
[root@milkv-duo]~# : > /tmp/rtsp_server.log
[root@milkv-duo]~# /root/stream/start_rtsp.sh /root/stream/cam0_gc2083_tuned.json
rtsp_server started pid 1138
log: /tmp/rtsp_server.log
preview: ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
dual config uses cam0 + cam1 when sensor_cfg dev_num=2
[root@milkv-duo]~# sleep 25

[root@milkv-duo]~# grep -iE 'GC2083|Init OK|VPSS|vi_vpss|fail|error' /tmp/rtsp_server.log | tail -15
vi-vpss-mode : 1
video-src-info : [{"buf-blk-cnt":4,"chn":0,"codec":"264","compress-mode":"tile","rtsp-url":"cam","venc-bind-vpss":true}]
[parse_sensor_name]-1893: sensor =  GCORE_GC2083_MIPI_2M_30FPS_10BIT
*** vi_vpss_mode:1
**** - bVpssBinding:1
**** - VpssChn:0
**** - bVencBindVpss:1
ViPipe:0,===GC2083 1080P 30fps 10bit LINE Init OK!===
author:        wanqiang.he    desc:          思博慧CV1812H_GC2083_RGB_mode_V1.0.0
VpssChn0 , Enable Vpss Grp: 0
VPSS init with src (1920, 1080) dst (1920, 1080).
CVI_VPSS_CreateGrp:0, s32Ret=0

# --- 命令：Mac ---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step8.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step8.mp4

# --- 结果：Mac ---
!?leading ~/Documents/learn/riscv/Camera> ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step8.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step8.mp4
ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, rtsp, from 'rtsp://192.168.42.1:8554/cam0':
  Metadata:
    title           :
    comment         : cam0
  Duration: N/A, start: 0.041278, bitrate: N/A
  Stream #0:0: Video: h264 (High), yuv420p(progressive), 1920x1080, 30 tbr, 90k tbn, start 0.041278
Stream mapping:
  Stream #0:0 -> #0:0 (copy)
Output #0, mp4, to 'gc2083_step8.mp4':
  Metadata:
    title           :
    comment         : cam0
    encoder         : Lavf62.12.101
  Stream #0:0: Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, q=2-31, 30 tbr, 90k tbn
Press [q] to stop, [?] for help
[mp4 @ 0x9c6c1c280] Timestamps are unset in a packet for stream 0. This is deprecated and will stop working in the future. Fix your code to set the timestamps properly
[vost#0:0/copy @ 0x9c6c64300] Non-monotonic DTS; previous: 0, current: 0; changing to 1. This may result in incorrect timestamps in the output file.
frame=   43 fps=0.0 q=-1.0 size=       0KiB time=00:00:01.39 bitrate=   0.3kbits/s speed=frame=   58 fps= 58 q=-1.0 size=       0KiB time=00:00:01.89 bitrate=   0.2kbits/s speed=frame=   73 fps= 49 q=-1.0 size=       0KiB time=00:00:02.39 bitrate=   0.2kbits/s speed=frame=   88 fps= 44 q=-1.0 size=       0KiB time=00:00:02.89 bitrate=   0.1kbits/s speed=frame=  103 fps= 41 q=-1.0 size=       0KiB time=00:00:03.39 bitrate=   0.1kbits/s speed=frame=  118 fps= 39 q=-1.0 size=       0KiB time=00:00:03.89 bitrate=   0.1kbits/s speed=frame=  133 fps= 38 q=-1.0 size=       0KiB time=00:00:04.39 bitrate=   0.1kbits/s speed=frame=  148 fps= 37 q=-1.0 size=       0KiB time=00:00:04.89 bitrate=   0.1kbits/s speed=frame=  163 fps= 36 q=-1.0 size=       0KiB time=00:00:05.39 bitrate=   0.1kbits/s speed=frame=  178 fps= 35 q=-1.0 size=       0KiB time=00:00:05.89 bitrate=   0.1kbits/s speed=frame=  194 fps= 35 q=-1.0 size=       0KiB time=00:00:06.43 bitrate=   0.1kbits/s speed=frame=  209 fps= 35 q=-1.0 size=       0KiB time=00:00:06.92 bitrate=   0.1kbits/s speed=frame=  224 fps= 34 q=-1.0 size=       0KiB time=00:00:07.42 bitrate=   0.1kbits/s speed=frame=  239 fps= 34 q=-1.0 size=       0KiB time=00:00:07.92 bitrate=   0.0kbits/s speed=frame=  254 fps= 34 q=-1.0 size=       0KiB time=00:00:08.42 bitrate=   0.0kbits/s speed=frame=  269 fps= 33 q=-1.0 size=       0KiB time=00:00:08.92 bitrate=   0.0kbits/s speed=frame=  284 fps= 33 q=-1.0 size=       0KiB time=00:00:09.42 bitrate=   0.0kbits/s speed=frame=  299 fps= 33 q=-1.0 size=       0KiB time=00:00:09.92 bitrate=   0.0kbits/s speed=frame=  314 fps= 33 q=-1.0 size=       0KiB time=00:00:10.42 bitrate=   0.0kbits/s speed=frame=  329 fps= 33 q=-1.0 size=       0KiB time=00:00:10.92 bitrate=   0.0kbits/s speed=frame=  344 fps= 33 q=-1.0 size=       0KiB time=00:00:11.42 bitrate=   0.0kbits/s speed=frame=  360 fps= 33 q=-1.0 size=       0KiB time=00:00:11.96 bitrate=   0.0kbits/s speed=frame=  375 fps= 32 q=-1.0 size=       0KiB time=00:00:12.46 bitrate=   0.0kbits/s speed=frame=  390 fps= 32 q=-1.0 size=       0KiB time=00:00:12.96 bitrate=   0.0kbits/s speed=frame=  405 fps= 32 q=-1.0 size=       0KiB time=00:00:13.46 bitrate=   0.0kbits/s speed=frame=  420 fps= 32 q=-1.0 size=       0KiB time=00:00:13.96 bitrate=   0.0kbits/s speed=frame=  435 fps= 32 q=-1.0 size=       0KiB time=00:00:14.46 bitrate=   0.0kbits/s speed=frame=  450 fps= 32 q=-1.0 size=       0KiB time=00:00:14.96 bitrate=   0.0kbits/s speed=[out#0/mp4 @ 0x9c7064240] video:245KiB audio:0KiB subtitle:0KiB other streams:0KiB global headers:0KiB muxing overhead: 2.475439%
frame=  452 fps= 32 q=-1.0 Lsize=     251KiB time=00:00:15.06 bitrate= 136.8kbits/s speed=1.06x elapsed=0:00:14.19
ffprobe version 8.1.1 Copyright (c) 2007-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'gc2083_step8.mp4':
  Metadata:
    major_brand     : isom
    minor_version   : 512
    compatible_brands: isomiso2avc1mp41
    encoder         : Lavf62.12.101
    comment         : cam0
  Duration: 00:00:15.03, start: 0.000000, bitrate: 137 kb/s
  Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, 133 kb/s, 30.08 fps, 30 tbr, 90k tbn (default)
    Metadata:
      handler_name    : VideoHandler
width=1920
height=1080
bit_rate=133783

# --- 结论 ---
未通过
```

**Agent 分析：**

- **板上 ✅：** tuned json 已创建并加载（日志可见 `vi-vpss-mode:1`、`buf-blk-cnt:4`、`compress-mode:tile`）；`GC2083 Init OK`；VPSS 仍 **1920×1080**。
- **Mac ❌：** `bit_rate=133783`（与 7A/6续 **完全一致**），无画面。
- **结论：** 增加 `vi-vpss-mode` / buffer / compress **不能**修复 8554 空流；问题不在 `cam0.json` 缺这几项。
- **ISSUE 主问题收口：** GC2083 可用 **`554/h264`**；**`8554/cam0` 对 GC2083 当前不可用**（`rtsp_server` 1080p 路径）。
- **阶段 B 矛盾：** 同日曾 8554 ~1.7 Mbps，疑为后续状态/固件/环境变化，需 Step 9 可选深挖或向 Milk-V 反馈。

---

## Step 9 — 8554 最后一轮软件对照 ✅ 已完成（未通过；已收口）

**目的：** 9A 试 `vi-vpss-mode:0`；9B 抓帧定性。**结论：** 8554 仍不可用；转 ISSUE-002。

**总通过标准：** 任一步 Mac 测 `8554/cam0`：`bit_rate` ≥ **800000** 且肉眼有画面 → ISSUE-001 可标 **8554 已恢复**。

---

## Step 9A — `vi-vpss-mode: 0` 对照 ✅ 已完成（未通过）

**目的：** Step 8 使用 `vi-vpss-mode:1`（日志 `bVpssBinding:1`，VPSS 1920×1080）。模式 **0** 走 VI→VENC 直连路径，与部分原厂 sample 一致；若 8554 空流来自 VPSS 绑定/缩放，本步可能恢复码率。

#### 执行前问答

**状态：** ✅ 可以执行了

**问题（用户填写）：**

```text
（可选；无问题可直接执行）
```

**Agent 解答：**

```text
1. 全程勿跑 camera-test，避免 sample_vi 占 VI。
2. 板上用 cat 创建 json（与 Step 8 相同，仅 vi-vpss-mode 改为 0）；仓库已有 `configs/stream/cam0_gc2083_mode0.json` 可对照。
3. 日志应出现 vi-vpss-mode : 0 与 *** vi_vpss_mode:0；若仍为 1 说明 json 未生效。
4. Mac 必须在 rtsp_server 启动约 25s 后再 ffprobe/ ffplay。
5. 9A 未通过再执行 Step 9B，不要跳步。
```

**通过标准：**

1. **板上：** `/tmp/rtsp_server.log` 含 `vi-vpss-mode : 0`（或 `vi_vpss_mode:0`）、`GC2083` + `Init OK`；`netstat` 见 `8554` LISTEN。
2. **Mac：** `ffprobe` 对 15s 录制文件 `bit_rate` ≥ **800000**，且 `ffplay` **肉眼有画面** → **9A 通过**，ISSUE-001 8554 问题可收口为已解决。
3. 仍 **~130k** 且无画面 → **9A 未通过**，继续 **Step 9B**（勿改其它变量重复测 9A）。

```shell
# --- 命令：板上（勿跑 camera-test）---
rmmod debris 2>/dev/null
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2

cat > /root/stream/cam0_gc2083_mode0.json << 'EOF'
{
    "rtsp-port": 8554,
    "vi-vpss-mode": 0,
    "buf1-blk-cnt": 4,
    "sensor-config-path": "/mnt/data/sensor_cfg.ini",
    "video-src-info": [{
        "chn": 0,
        "rtsp-url": "cam",
        "buf-blk-cnt": 4,
        "codec": "264",
        "venc-bind-vpss": true,
        "compress-mode": "tile"
    }]
}
EOF

: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0_gc2083_mode0.json
sleep 25
netstat -ln | grep 8554
grep -iE 'vi-vpss|vi_vpss|GC2083|Init OK|VPSS|fail|error' /tmp/rtsp_server.log | tail -20

# --- 结果（执行后原样粘贴在下方）---
[root@milkv-duo]~# netstat -ln | grep 8554
tcp        0      0 0.0.0.0:8554            0.0.0.0:*               LISTEN
[root@milkv-duo]~# grep -iE 'vi-vpss|vi_vpss|GC2083|Init OK|VPSS|fail|error' /tmp/rtsp_server.log | tail -20
vi-vpss-mode : 0
video-src-info : [{"buf-blk-cnt":4,"chn":0,"codec":"264","compress-mode":"tile","rtsp-url":"cam","venc-bind-vpss":true}]
[parse_sensor_name]-1893: sensor =  GCORE_GC2083_MIPI_2M_30FPS_10BIT
*** vi_vpss_mode:0
**** - bVpssBinding:1
**** - VpssChn:0
**** - bVencBindVpss:1
ViPipe:0,===GC2083 1080P 30fps 10bit LINE Init OK!===
author:        wanqiang.he    desc:          思博慧CV1812H_GC2083_RGB_mode_V1.0.0
VpssChn0 , Enable Vpss Grp: 0
VPSS init with src (1920, 1080) dst (1920, 1080).
CVI_VPSS_CreateGrp:0, s32Ret=

# --- 命令：Mac（rtsp_server 已跑满 25s）---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step9a.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step9a.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果：Mac ---
ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, rtsp, from 'rtsp://192.168.42.1:8554/cam0':
  Metadata:
    title           :
    comment         : cam0
  Duration: N/A, start: 0.046778, bitrate: N/A
  Stream #0:0: Video: h264 (High), yuv420p(progressive), 1920x1080, 30 tbr, 90k tbn, start 0.046778
Stream mapping:
  Stream #0:0 -> #0:0 (copy)
Output #0, mp4, to 'gc2083_step9a.mp4':
  Metadata:
    title           :
    comment         : cam0
    encoder         : Lavf62.12.101
  Stream #0:0: Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, q=2-31, 30 tbr, 90k tbn
Press [q] to stop, [?] for help
[mp4 @ 0x735024280] Timestamps are unset in a packet for stream 0. This is deprecated and will stop working in the future. Fix your code to set the timestamps properly
[vost#0:0/copy @ 0x734c5c300] Non-monotonic DTS; previous: 0, current: 0; changing to 1. This may result in incorrect timestamps in the output file.
[out#0/mp4 @ 0x73506c240] video:33KiB audio:0KiB subtitle:0KiB other streams:0KiB global headers:0KiB muxing overhead: 18.158371%
frame=  452 fps= 32 q=-1.0 Lsize=      39KiB time=00:00:15.06 bitrate=  21.2kbits/s speed=1.06x elapsed=0:00:14.19
ffprobe version 8.1.1 Copyright (c) 2007-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'gc2083_step9a.mp4':
  Metadata:
    major_brand     : isom
    minor_version   : 512
    compatible_brands: isomiso2avc1mp41
    encoder         : Lavf62.12.101
    comment         : cam0
  Duration: 00:00:15.03, start: 0.000000, bitrate: 21 kb/s
  Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, 17 kb/s, 30.08 fps, 30 tbr, 90k tbn (default)
    Metadata:
      handler_name    : VideoHandler
width=1920
height=1080
bit_rate=17955
ffplay version 8.1.1 Copyright (c) 2003-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, rtsp, from 'rtsp://192.168.42.1:8554/cam0':
  Metadata:
    title           :
    comment         : cam0
  Duration: N/A, start: 0.034356, bitrate: N/A
  Stream #0:0: Video: h264 (High), yuv420p(progressive), 1920x1080, 30 tbr, 90k tbn, start 0.034356
2026-06-30 15:39:33.864 ffplay[37870:5879369] error messaging the mach port for IMKCFRunLoopWakeUpReliable
  13.45 M-V:  0.032 fd=   2 aq=    0KB vq=    1KB sq=    0B

# --- 结论 ---
未通过，无画面出现

```

**Agent 分析：**

```text
- **板上 ✅（标准 1）：** `vi-vpss-mode : 0`、`vi_vpss_mode:0`；`GC2083 Init OK`；`8554` LISTEN。
- **注意：** 尽管 mode=0，日志仍打印 `bVpssBinding:1`、`bVencBindVpss:1`，且 `VPSS init (1920,1080)` —— json 里 `venc-bind-vpss: true` 可能使 rtsp_server 仍走 VPSS 路径；但即便 mode 已切换，问题依旧。
- **Mac ❌（标准 2/3）：** 15s 录制 `bit_rate=17955`（~18 kb/s），低于 Step 8 的 ~133k；流声明 1920×1080@30、452 帧但仅 33KiB 视频数据 → 近乎空 H.264；ffplay **无画面**。
- **判定：9A 未通过。** `vi-vpss-mode` 从 1 改为 0 **不能**恢复 8554 GC2083 出图。
- **与 554 对照不变：** GC2083 硬件与 sensor 配置正常；问题稳定在 `rtsp_server` 8554/1080p 编码链。
- **下一步：** Step 9B — **勿重启 rtsp_server**，Mac 抓一帧判断纯黑 vs 有像素。
```

---

## Step 9B — 抓帧诊断 ✅ 已完成

**目的：** 确认 8554 流是 **编码正常的纯黑帧**（传感器/ISP 无有效 YUV 进 VENC），还是 **码流异常**。结论用于 ISSUE-001 归档或 ISSUE-002。

**前置：** Step 9A 已 **未通过**；**8554 rtsp_server 须仍在运行**（`cam0_gc2083_mode0.json`），**勿 reboot、勿 kill、勿重跑 start_rtsp**。

#### 执行前问答

**状态：** ✅ 可以执行了

**Agent 解答：**

```text
1. 若 9A 后已 Ctrl+C / kill rtsp_server，需用相同 mode0 json 重新 start_rtsp.sh 并 sleep 25s 再抓帧。
2. 理想情况：直接在当前仍运行的 8554 上执行 Mac 命令即可。
3. 抓帧后肉眼看 gc2083_step9b.png：全黑 → ISP/YUV 未进编码器；有轮廓/噪声 → 编码/解码或 GOP 问题。
```

**通过标准：**

1. Mac 成功生成 `gc2083_step9b.png`（或 `.jpg`），文件大小 **> 1 KB**。
2. 用下方 `file` / 肉眼看图：**全黑** vs **有轮廓/噪声** — 在 `# --- 结论 ---` 二选一写明。
3. 可选：`ffprobe` 对 Step 9A 的 mp4 记录 `codec_name`、`width`、`height`（应仍为 1920×1080 或流声明分辨率）。

```shell
# --- 命令：Mac（8554 仍在跑，9A 未通过时）---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -frames:v 1 -update 1 -y gc2083_step9b.png
file gc2083_step9b.png
ffprobe -show_entries stream=codec_name,width,height,bit_rate -of default=nw=1 gc2083_step9a.mp4

# --- 结果（执行后原样粘贴在下方）---
ffmpeg version 8.1.1 Copyright (c) 2000-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, rtsp, from 'rtsp://192.168.42.1:8554/cam0':
  Metadata:
    title           :
    comment         : cam0
  Duration: N/A, start: 0.044344, bitrate: N/A
  Stream #0:0: Video: h264 (High), yuv420p(progressive), 1920x1080, 30 tbr, 90k tbn, start 0.044344
Stream mapping:
  Stream #0:0 -> #0:0 (h264 (native) -> png (native))
Press [q] to stop, [?] for help
Output #0, image2, to 'gc2083_step9b.png':
  Metadata:
    title           :
    comment         : cam0
    encoder         : Lavf62.12.101
  Stream #0:0: Video: png, rgb24(pc, gbr/unknown/unknown, progressive), 1920x1080, q=2-31, 200 kb/s, 30 fps, 30 tbn
    Metadata:
      encoder         : Lavc62.28.101 png
[out#0/image2 @ 0x844c04780] video:8KiB audio:0KiB subtitle:0KiB other streams:0KiB global headers:0KiB muxing overhead: unknown
frame=    1 fps=0.0 q=-0.0 Lsize=N/A time=00:00:00.03 bitrate=N/A speed=0.587x elapsed=0:00:00.05
gc2083_step9b.png: PNG image data, 1920 x 1080, 8-bit/color RGB, non-interlaced
ffprobe version 8.1.1 Copyright (c) 2007-2026 the FFmpeg developers
  built with Apple clang version 21.0.0 (clang-2100.0.123.102)
  configuration: --prefix=/opt/homebrew/Cellar/ffmpeg/8.1.1 --enable-shared --enable-pthreads --enable-version3 --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libsvtav1 --enable-libopus --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libvmaf --enable-libvpx --enable-libx265 --enable-openssl --enable-videotoolbox --enable-audiotoolbox --enable-neon
  libavutil      60. 26.101 / 60. 26.101
  libavcodec     62. 28.101 / 62. 28.101
  libavformat    62. 12.101 / 62. 12.101
  libavdevice    62.  3.101 / 62.  3.101
  libavfilter    11. 14.101 / 11. 14.101
  libswscale      9.  5.101 /  9.  5.101
  libswresample   6.  3.101 /  6.  3.101
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'gc2083_step9a.mp4':
  Metadata:
    major_brand     : isom
    minor_version   : 512
    compatible_brands: isomiso2avc1mp41
    encoder         : Lavf62.12.101
    comment         : cam0
  Duration: 00:00:15.03, start: 0.000000, bitrate: 21 kb/s
  Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1920x1080, 17 kb/s, 30.08 fps, 30 tbr, 90k tbn (default)
    Metadata:
      handler_name    : VideoHandler
codec_name=h264
width=1920
height=1080
bit_rate=17955

# --- 结论 ---
抓帧成功；PNG 1920×1080 仅 8KiB → 近黑/均匀帧（用户填「失败」指仍无可见画面，非命令失败）
```

**Agent 分析：**

```text
- **抓帧 ✅（标准 1）：** `gc2083_step9b.png` 生成；`file` 确认 1920×1080 PNG。
- **帧内容：** 编码输出仅 **8KiB**（正常场景 PNG 通常数百 KB 以上）→ **近黑或极低熵画面**；与 ffplay 无画面、H.264 ~18k 一致。
- **流性质：** H.264 **可正常解码**为 PNG → **非**「码流损坏/无法解码」；是 **VENC 在编码有效但近乎全黑的 YUV**。
- **根因细化：** `rtsp_server` 路径上 ISP Init OK，但 **进 VENC 的帧无有效图像**；554 `sample_vi_fd` 同传感器有图 → 差异在 **rtsp_server 的 VI/VPSS/VENC 绑定与分辨率链**（非模组硬件）。
- **9B 诊断完成。** ISSUE-001 收口；下一步 **ISSUE-002 Step 1**：`venc-bind-vpss: false` 尝试真正绕过 VPSS。
```

**ISSUE-001 收口说明：** 见下方表格；8554 继续攻 → [DEBUG_SESSION_ISSUE002.md](./DEBUG_SESSION_ISSUE002.md)

---


## ISSUE-001 收口 — GC2083 使用建议（Step 8 后生效）

| 需求 | 做法 | URL / 码率 |
|------|------|------------|
| **GC2083 预览** | `camera-test.sh` | `rtsp://192.168.42.1:554/h264`，720p，**有画面** |
| **OV5647 / 安全栈** | `cam0.json` + OV5647 ini/bin | `8554/cam0`，~4 Mbps ✅ |
| **GC2083 on 8554** | `rtsp_server` + mode0/mode1 json | ~18k～133k，**无画面** ❌ |

**新建 ISSUE：** 已开 **ISSUE-002** — [DEBUG_SESSION_ISSUE002.md](./DEBUG_SESSION_ISSUE002.md)（Step 1：`venc-bind-vpss: false`）

---

## 变更记录


| 日期         | 变更                                                 |
| ---------- | -------------------------------------------------- |
| 2026-06-05 | 从 monolithic `DEBUG_SESSION.md` 迁入 v2 目录 |
| 2026-06-05 | Step 6 部分完成：554 有画面；展开 Step 6续 |
| 2026-06-05 | WORKFLOW：命令与结果合并为单 `shell` 块；Step 6续 已改用新布局 |
| 2026-06-05 | Step 6续 未通过：554 有图/8554 135k 无图；展开 Step 7 |
| 2026-06-05 | Step 7 未通过；7B 缺 json；展开 Step 8 补测 tuned json |
| 2026-06-05 | Step 8 未通过；ISSUE 收口 + 554 workaround；Step 9 可选 |
| 2026-06-08 | 展开 Step 9A/9B；9A 可执行（vi-vpss-mode 0） |
| 2026-06-30 | Step 9A 未通过（~18k）；展开 Step 9B 抓帧 |
| 2026-06-30 | Step 9B 完成（近黑帧）；ISSUE-001 收口；创建 ISSUE-002 |

