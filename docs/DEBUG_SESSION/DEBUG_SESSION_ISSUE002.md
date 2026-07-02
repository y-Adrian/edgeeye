# ISSUE-002: GC2083 rtsp_server 8554 1080p 空流（继承 ISSUE-001）

**状态：** ⚠️ **部分收口**（Step 6 ❌；根因未修；见文末收口节）

> **前置结论（ISSUE-001）：** GC2083 硬件正常；`camera-test` → `554/h264` 720p **有画面**；`rtsp_server` → `8554/cam0` Init OK 但 **~18k～133k 空流**；9B 抓帧为 **1920×1080 近黑 PNG（8KiB）** → VENC 在编码，但 **YUV 输入近乎全黑**。

---

## ISSUE-002 通用问答

**问题（用户填写）：**

```text
（可选）
```

**Agent 解答：**

```text
ISSUE-001 已收口。本 ISSUE 专注让 GC2083 在 rtsp_server/8554 出图，或确认需 Milk-V 官方 json/固件支持。
```

---

## 已知事实（Agent 维护）

- 继承 ISSUE-001 全部「已排除」项：PQ 链、双摄干扰、冷启动、json buf/vi-vpss/compress、vi-vpss-mode 0/1 翻转
- 9A：`vi-vpss-mode:0` 时日志 **仍** `bVpssBinding:1`（json 含 `venc-bind-vpss: true`）
- 9B：H.264 可解码；单帧 PNG **8KiB@1080p** → **近黑/均匀帧**，非码流损坏
- 工作路径：`554/h264`（`sample_vi_fd`）✅ vs `8554/cam0`（`rtsp_server`）❌
- Step 1（2026-07-01）：`venc-bind-vpss:false` 已生效（`bVencBindVpss:0`），但 `bVpssBinding:1`、VPSS 仍初始化；Mac **无画面** → **未通过**
- Step 2（2026-07-01）：`h264_min.json` 在板上 **554/stream0** 正常监听；Mac 误测 **8554/cam0** → `Connection refused`（**非** Step 1 类空流失败）
- Step 2 续（2026-07-01）：**554/stream0** 与 **8554/cam0**（最小 json）均 **无画面**；**camera-test → 554/h264 有画面** → 问题在 **rtsp_server 路径**，与端口无关
- Step 3（2026-07-01）：`enable-set-pq-bin:true` + 显式 `sdr-pq-bin-path`；PQBIN 已加载；`2083 vs 2053` mismatch（**GC2083 正常警告**，见 CAMERA_VERIFY）；Mac **仍无画面** → **H2（PQ 未加载）排除**
- 对照：`sample_vi_fd` **720p** ✅ vs `rtsp_server` **1080p** ❌；OV5647 在同 rtsp_server @8554 **有图** → **GC2083 + rtsp_server 1080p** 特异
- Step 4B（2026-07-01）：`554/h264` 录制 **有画面** → workaround **复验通过**
- Step 5（2026-07-01）：**分时** GC2083@554 + OV5647@8554/cam0 **均有画面**
- Step 6（2026-07-01）：**同时** camera-test + rtsp_server → 554 **Connection refused**、8554 **无画面**、`CVI_VENC_GetStream 0xc0078012` → **MMF 互斥，混合双栈不可行**

---

## Step 1 — `venc-bind-vpss: false` + `vi-vpss-mode: 0` ❌ 未通过

**目的：** 9A 虽设 `vi-vpss-mode:0`，但 `venc-bind-vpss: true` 仍启用 VPSS（日志 `bVpssBinding:1`）。本步关闭 VPSS 绑定，走 VI→VENC 直连，对照 9B「黑帧来自 VPSS 路径」假设。

#### 执行前问答

**状态：** ✅ 可以执行了

**问题（用户填写）：**

```text
（可选）
```

**Agent 解答：**

```text
1. 勿跑 camera-test（避免占 VI）。
2. 板上 cat 创建 novpss json（仓库对照 `configs/stream/cam0_gc2083_novpss.json`）。
3. 日志期望：vi_vpss_mode:0 且 bVpssBinding:0（或不再 Enable Vpss Grp）；若仍 bVpssBinding:1 说明 json 字段被忽略。
4. Mac 测 8554/cam0：bit_rate ≥ 800000 且有画面 → 本步通过。
```

**通过标准：**

1. **板上：** 日志 `GC2083 Init OK`；`8554` LISTEN；**优先**见 `bVpssBinding:0` 或日志无 `Enable Vpss Grp`。
2. **Mac：** 15s 录制 `bit_rate` ≥ **800000**，`ffplay` **肉眼有画面** → **通过**。
3. 仍 ~130k/无画面 → **未通过**，进入 Step 2。

```shell
# --- 命令：板上 ---
rmmod debris 2>/dev/null
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2

cat > /root/stream/cam0_gc2083_novpss.json << 'EOF'
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
        "venc-bind-vpss": false,
        "compress-mode": "tile"
    }]
}
EOF

: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0_gc2083_novpss.json
sleep 25
netstat -ln | grep 8554
grep -iE 'vi-vpss|vi_vpss|Vpss|GC2083|Init OK|fail|error' /tmp/rtsp_server.log | tail -25

# --- 结果（执行后原样粘贴在下方）---
vi-vpss-mode : 0
video-src-info : [{"buf-blk-cnt":4,"chn":0,"codec":"264","compress-mode":"tile","rtsp-url":"cam","venc-bind-vpss":false}]
[parse_sensor_name]-1893: sensor =  GCORE_GC2083_MIPI_2M_30FPS_10BIT
*** vi_vpss_mode:0
**** - bVpssBinding:1
**** - VpssChn:0
**** - bVencBindVpss:0
ViPipe:0,===GC2083 1080P 30fps 10bit LINE Init OK!===
author:        wanqiang.he    desc:          思博慧CV1812H_GC2083_RGB_mode_V1.0.0
VpssChn0 , Enable Vpss Grp: 0
VPSS init with src (1920, 1080) dst (1920, 1080).
CVI_VPSS_CreateGrp:0, s32Ret=0

# --- 命令：Mac ---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step1.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step1.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果：Mac ---
无画面

# --- 结论 ---
未通过；Mac 无画面；bVencBindVpss=0（较 Step 9A 有变化）；bVpssBinding 仍为 1；VPSS 仍 Enable
```

**Agent 分析：**

```text
- **板上（部分达标）：** `vi-vpss-mode:0`、json 解析含 `venc-bind-vpss:false`；`GC2083 Init OK`；8554 应在 LISTEN。
- **关键变化 vs ISSUE-001 Step 9A：** `bVencBindVpss:0`（此前为 1）→ json 的 `venc-bind-vpss:false` **已生效**，VENC 不再绑定 VPSS。
- **仍未改变：** `bVpssBinding:1`，且日志仍有 `Enable Vpss Grp: 0`、`VPSS init (1920,1080)` → rtsp_server **仍会创建/初始化 VPSS**，只是 VENC 不绑 VPSS。
- **Mac ❌：** ffplay **无画面**（与 9A 一致）→ 仅关 VENC-VPSS 绑定 **不足以**恢复 GC2083 @ 8554 出图。
- **假设判定：**「黑帧 purely 来自 VENC bind VPSS」→ **未证实**；更可能是 GC2083 在 rtsp_server 整条 VI/VPSS/ISP 链上与 554 sample 行为不同，或需原厂最小 json / 不同分辨率链。
- **下一步：** Step 2 — 对照 `duo-sdk/cvi_rtsp/test/h264.json` 最小配置 + 确认 554 对照仍正常。
```

---

## Step 2 — 原厂最小 json + 554 对照 ⚠️ 部分完成（2B 端点测错）

**目的：** Step 1 未通过。用 SDK 最小 `h264.json` 排除「自写 json 字段干扰」；并复验 `554/h264` 确认 GC2083 硬件链仍正常。

**状态：** ⚠️ 2B 板上已启动但 Mac 测错 URL/端口；2A 未执行；需补测

**通过标准：**

1. **2A（554 对照）：** `sample_vi` / `camera-test` 路径仍有画面 → 硬件/ini/PQ 仍 OK。
2. **2B（最小 json）：** `h264.json` 启动后 Mac `bit_rate ≥ 800000` 且有画面 → 通过；否则记录 bit_rate，进入 Step 2C（向 Milk-V 索取官方 GC2083 json 或查 SDK sample）。

```shell
# --- 2A：554 对照（GC2083 硬件仍正常？）---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
# 按仓库 CAMERA_VERIFY.md / rtsp_single_gc2083 的 554 路径启动 sample_vi
# Mac: ffplay rtsp://192.168.42.1:554/h264

# --- 2B：最小 h264.json @ 8554 ---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
sleep 2
cat > /root/stream/h264_min.json << 'EOF'
{
    "video-src-info": [{
        "codec": "264"
    }]
}
EOF
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/h264_min.json
sleep 25
grep -iE 'GC2083|Init OK|fail|error|Vpss|vi_vpss' /tmp/rtsp_server.log | tail -25

# Mac:
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step2.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step2.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果 ---
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
[tcp @ 0xb7cc58000] Connection to tcp://192.168.42.1:8554?timeout=0 failed: Connection refused
[in#0 @ 0xb7cc10000] Error opening input: Connection refused
Error opening input file rtsp://192.168.42.1:8554/cam0.
Error opening input files: Connection refused
exit 195

# --- 结论 ---
Step 2B Mac：Connection refused（8554/cam0）— 非黑流结论；2A 未执行


**Agent 分析：**

```text
**根因（2B Mac Connection refused）：** SDK `h264.json` 仅含 `codec:264`。`default_ctx()` 默认 `rtspPort=0` → live555 监听 **554**（见 `cvi_rtsp.hpp`：`port==0?554`）；默认 `rtspURL=stream` → 路径 **/stream0**，不是 `/cam0`。Mac 仍测 `8554/cam0` → **端点错误**，与 Step 1「Init OK 但空流」不是同一类失败。

**板上实锤（SSH 2026-07-01）：**
- `rtsp_server` pid 1824 存活，`/root/stream/h264_min.json`
- `netstat`：**554 LISTEN**，8554 **未监听**
- 日志：`rtspPort:0`，`rtspURL:stream`，`GC2083 Init OK`，`bVpssBinding:1`，`bVencBindVpss:1`，VPSS 1920×1080 — 与 Step 1 前 cam0.json 默认链一致

**2A：** 未执行，554 `camera-test` / `sample_vi` 硬件对照仍缺。

**判定：** Step 2 **不能**记为「最小 json 也黑屏」；当前只能记「最小 json 在默认 554/stream0 可启动」。是否出图须 Mac 测正确 URL。

**补测（按序）：**
1. 当前进程可直接测：`ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/stream0`
2. 2A：`camera-test` → `554/h264`（与 ISSUE-001 Step 6 同）
3. 2B 修正（8554/cam0 对照）：在最小 json 上**仅**补 `rtsp-port` + `rtsp-url` + `sensor-config-path`（见 Step 2 续）
```

---

## Step 2 续 — 补测（端点修正）✅ 已完成

**目的：** 完成 Step 2 本意：① 554 硬件对照；② 最小 json 在 **8554/cam0** 是否与自写 json 同病。

**状态：** ✅ 已完成（结论见 Agent 分析 → Step 3）

**通过标准：**

1. **2A：** `554/h264` 有画面 → 硬件链仍 OK。
2. **2B-1（SDK 默认端点）：** `554/stream0` 有画面且 `bit_rate ≥ 800000` → 说明最小 json 本身能出图（在 554）。
3. **2B-2（8554 对照）：** 最小 json + 显式 `rtsp-port:8554` + `rtsp-url:cam` 后，与 Step 1 同测 `8554/cam0`；有画面 → 通过；仍无画面 → 进入 Step 2C。

```shell
# --- 命令：2B-1 Mac（h264_min 若在跑可直接测）---
ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/stream0
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:554/stream0 -c copy -t 15 gc2083_step2_554.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step2_554.mp4

# --- 结果：2B-1 Mac ---
无画面

# --- 命令：2A 板上（先停 rtsp_server）---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
sh /mnt/system/usr/bin/camera-test.sh

# --- 命令：2A Mac（camera-test 运行期间，另开终端）---
ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264

# --- 结果：2A Mac ---
有画面

# --- 命令：2B-2 板上（camera-test Ctrl+C 后）---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
sleep 2
cat > /root/stream/h264_min_8554.json << 'EOF'
{
    "rtsp-port": 8554,
    "sensor-config-path": "/mnt/data/sensor_cfg.ini",
    "video-src-info": [{
        "rtsp-url": "cam",
        "codec": "264"
    }]
}
EOF
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/h264_min_8554.json
sleep 25
netstat -ln | grep 8554
grep -iE 'rtspPort|rtspURL|GC2083|Init OK|Vpss|bVenc|bVpss' /tmp/rtsp_server.log | tail -20

# --- 命令：2B-2 Mac ---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step2b2.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step2b2.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果：2B-2 Mac ---
无画面

# --- 结论 ---
2B-1 554/stream0 无画面；2A 554/h264 有画面；2B-2 8554/cam0 无画面 → 未通过；问题在 rtsp_server 路径非端口
```

**Agent 分析：**

```text
**结果矩阵（Step 2 续）：**

| 步骤 | 程序 | URL | 编码分辨率 | 画面 |
|------|------|-----|------------|------|
| 2B-1 | rtsp_server + h264_min | 554/stream0 | 1080p | ❌ |
| 2A | camera-test (sample_vi_fd) | 554/h264 | **720p** | ✅ |
| 2B-2 | rtsp_server + h264_min_8554 | 8554/cam0 | 1080p | ❌ |

**核心结论：**
1. **与 8554 端口无关** — 同一 rtsp_server 在 554 也无画面；8554 不是根因。
2. **与 json 复杂度无关** — SDK 最小 json（仅 codec）+ 显式 8554/cam 仍黑；自写字段不是主因。
3. **硬件 / ini / PQ 正常** — 2A 在相同 GC2083 ini + PQ 软链下 **有画面**。
4. **分裂点在二进制与分辨率链** — `camera-test` → `sample_vi_fd`（`vi_vo_utils.c` 固定 **1280×720** VPSS/VENC）；`rtsp_server` → `vpss_helper` 令 **dst=src=1920×1080**（日志已证实）。
5. **非「rtsp_server 全坏」** — OV5647 在同板 `rtsp_server` @8554/cam0 **有图**（verify_board）；仅 **GC2083 + rtsp_server + 1080p** 组合失败，与 ISSUE-001 9B「1080p 近黑 PNG」一致。

**根因假设（按优先级）：**
- **H1（最可能）：** GC2083 在 rtsp_server 的 **1080p VPSS/VENC 链**产出近黑 YUV；sample_vi 经 VPSS **缩到 720p** 后 ISP/图像正常。json **无** width/height 字段（`set_videosrc` 未解析），无法仅靠配置降分辨率。
- **H2：** rtsp_server 默认 `enable_set_pq_bin:0`，PQ 仅靠 `/mnt/cfg/param/cvi_sdr_bin` 软链；显式开启 PQ 路径待 Step 3A 验证。
- **H3：** 历史 CAMERA_VERIFY 阶段 B 曾 1.77Mbps@1080p — 可能当时固件/状态不同；**当前可复现态**以 Step 2 续为准。

**Step 2 总判定：** ❌ 未通过（8554 GC2083 仍无图）；但 **收窄**为「rtsp_server 1080p 路径」问题，非端口/json 笔误。
```

---

## Step 3 — PQ 显式加载 + 对齐 sample_vi 参数 ❌ 未通过

**目的：** Step 2 续已把问题收窄到 **GC2083 × rtsp_server × 1080p**。本步先测 json 能改的 ISP/PQ/VENC 参数；若仍失败，评估 720p workaround 或向 Milk-V 索取官方 GC2083 rtsp 配置。

**状态：** ✅ 已完成（未通过 → Step 4）

**通过标准：**

1. **3A（PQ 显式）：** `enable-set-pq-bin` + `sdr-pq-bin-path` 后 Mac 有画面 → 根因为 PQ 未加载。
2. **3B（VENC 参数）：** 提高 `bitrate`（对齐 sample_vi 的 8000 kbps 量级）后仍无画面 → 排除「码率过低」为主因（低码率是黑帧结果而非原因）。
3. **二者均失败** → Step 3C：产品 workaround（GC2083 走 `camera-test`/554，或 SDK 补丁支持 720p）；并行向 Milk-V 问 GC2083 @ rtsp_server 官方 json。

```shell
# --- 命令：板上 ---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin

cat > /root/stream/cam0_gc2083_pq.json << 'EOF'
{
    "rtsp-port": 8554,
    "sensor-config-path": "/mnt/data/sensor_cfg.ini",
    "enable-set-pq-bin": true,
    "sdr-pq-bin-path": "/mnt/cfg/param/cvi_sdr_bin_GC2083",
    "video-src-info": [{
        "rtsp-url": "cam",
        "codec": "264",
        "bitrate": 4000,
        "max-bitrate": 8000
    }]
}
EOF

: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0_gc2083_pq.json
sleep 25
netstat -ln | grep 8554
grep -iE 'pq|GC2083|Init OK|enable_set_pq|mismatch|Vpss|bVenc' /tmp/rtsp_server.log | tail -25

# --- 结果：板上 ---
enable-set-pq-bin : true
sdr-pq-bin-path : "/mnt/cfg/param/cvi_sdr_bin_GC2083"
[parse_sensor_name]-1893: sensor =  GCORE_GC2083_MIPI_2M_30FPS_10BIT
*** vi_vpss_mode:1
*** teaisp-pq-bmodel:
*** enable_set_pq_bin:1
*** sdr_pq_bin_path:/mnt/cfg/param/cvi_sdr_bin_GC2083
*** wdr_pq_bin_path:
**** - bVpssBinding:1
**** - VpssChn:0
**** - bVencBindVpss:1
**** - enableTeaisppq:0
**** - venc_cfg.pqp:32
**** - venc_cfg.s32IPQpDelta:2
ViPipe:0,===GC2083 1080P 30fps 10bit LINE Init OK!===
PQBIN message
author:        wanqiang.he    desc:          思博慧CV1812H_GC2083_RGB_mode_V1.0.0
sensorName(0) mismatch, mwSns:2083 != pqBinSns:2053
VpssChn0 , Enable Vpss Grp: 0
VPSS init with src (1920, 1080) dst (1920, 1080).
CVI_VPSS_CreateGrp:0, s32Ret=0

# --- 命令：Mac ---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step3a.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step3a.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果：Mac ---
无画面

# --- 结论 ---
未通过；PQ 显式加载后仍无画面；2083 vs 2053 mismatch 为 GC2083 已知警告（不挡出图）
```

**Agent 分析：**

```text
**板上（部分达标）：**
- json 字段生效：`enable_set_pq_bin:1`，`sdr_pq_bin_path` 指向 `cvi_sdr_bin_GC2083`
- `PQBIN message` 已打印 → PQ bin **确实被 rtsp_server 加载**（H2 排除）
- `GC2083 Init OK`；VPSS 仍 **1920×1080 → 1920×1080**；8554 LISTEN
- `sensorName(0) mismatch, mwSns:2083 != pqBinSns:2053`：**非本步根因**
  - CAMERA_VERIFY 已记：`2083 vs 2053` 对 GC2083 **可有**，阶段 B 验证不影响
  - `isp_bin.c` 对该 mismatch 仅打印警告后 `return CVI_SUCCESS`（不阻断）
  - OV5647 用错 bin 时的 `22087 vs 2053` 才是致命错配；与 GC2083 不同

**Mac ❌：** 仍无画面 → **显式 PQ + 提高 bitrate 不足以修复**

**假设更新：**
- H2（PQ 未加载）→ **排除**（本步已显式加载）
- H1（rtsp_server 1080p 链 vs sample_vi 720p 链）→ **加强**

---

**用户问：为何调试中 `camera-test` → `554/h264` 能有画面，而 `rtsp_server` → `8554/cam0` 不行？**

**不是矛盾**，是 **两套完全不同的媒体程序 + 分辨率链**，可共用同一 `sensor_cfg.ini` 和 PQ 软链：

| 对比项 | camera-test（有画面） | rtsp_server（无画面） |
|--------|----------------------|----------------------|
| 程序 | `sample_vi_fd`（`camera-test.sh`） | `/mnt/system/usr/test/rtsp_server` |
| RTSP URL | `554/h264` | `8554/cam0`（或 554/stream0） |
| 编码分辨率 | **1280×720**（`vi_vo_utils.c` 硬编码） | **1920×1080**（传感器原生，`vpss_helper` dst=src） |
| VPSS | 传感器 1080p → **缩到 720p** 再送 VENC | 1080p **直通** VPSS/VENC |
| 码率默认 | ~8000 kbps 量级 | 256 kbps 默认（黑帧时更低，是结果非原因） |

**通俗说：** 硬件和 PQ 没问题；GC2083 在 **sample_vi 的 720p 缩放链**能正常出图，在 **rtsp_server 的 1080p 全分辨率链**产出近黑 YUV。OV5647 在同 rtsp_server @1080p 有图，说明是 **GC2083 与 rtsp_server 1080p 路径的兼容性**问题，不是「板子坏了」或「ini 错了」。

**Step 3 判定：** ❌ 未通过。json 可调项（PQ 显式、bitrate）已穷尽；下一步须 **换路径**（720p workaround / Milk-V 官方配置 / SDK 补丁），见 Step 4。
```

---

## Step 4 — 路径决策：workaround vs 原厂支持 ⚠️ 部分完成（4B ✅）

**目的：** Step 1–3 已排除：端口、json 复杂度、venc-bind-vpss、PQ 软链/显式加载。剩余可行方向是 **对齐 sample_vi 720p 链** 或 **索取 Milk-V 官方 GC2083 rtsp 配置/固件**。

**状态：** ⚠️ 4B workaround 已验证；4A/4C 未做；M1 严格目标（8554/rtsp_server）仍失败

**通过标准：**

1. **4A（Milk-V）：** 论坛/GitHub issue 获得 GC2083 @ `rtsp_server` 可用 json 或固件版本 → 按官方配方复测 `8554/cam0` 有画面。
2. **4B（产品 workaround）：** 板上 `camera-test` @ `554/h264` 有画面 + 脚本将流 relay/映射到 `8554/cam0`（或产品接受 cam0=554 文档化）→ **形态三 M1 临时验收**。
3. **4C（SDK 补丁）：** 为 `rtsp_server` json 增加 `width`/`height`（720p）并验证 → 长期方案。

**4B 快速验证（不依赖 Milk-V 回复，可先跑）：**

```shell
# --- 命令：板上（终端 A，保持运行）---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
sh /mnt/system/usr/bin/camera-test.sh

# --- 命令：Mac（camera-test 运行期间）---
ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:554/h264 -c copy -t 15 gc2083_workaround_554.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_workaround_554.mp4

# --- 结果：Mac ---
​视频录制成功，有画面

# --- 结论 ---
通过（4B）；GC2083 经 camera-test/554 可用；不等于 8554/rtsp_server 已修复
```

**Agent 分析：**

```text
**4B ✅（workaround 复验）：**
- Mac 录制 `554/h264` **有画面** → 与 Step 2A/2 续结论一致，**可重复**
- 满足 ISSUE-001 已建立的 **554 预览路径**；PRODUCT_FORM3 §5 过渡方案成立

**4A / 4C：** 未执行（待并行）

**对里程碑的影响：**

| 目标 | 状态 | 说明 |
|------|------|------|
| M1 严格：GC2083 @ `8554/cam0`（rtsp_server） | ❌ **未过** | Step 1–3 已穷尽 json 调参 |
| M1 过渡：`554/h264`（camera-test） | ✅ **可用** | 本步复验通过 |
| 形态三完成 | ❌ | PRODUCT_FORM3 明确要求不能长期依赖 554 |

**架构约束（决定 Step 5）：**
1. **VI 独占** — `camera-test`（sample_vi）与 `rtsp_server` **不能同时**占 J1；混搭双摄 `cam_dual.json` 仍走 rtsp_server → cam0(GC2083) 预期仍黑
2. **OV5647** 已证实可走 `rtsp_server` @8554/cam1 → M2 可能是「cam0=554 + cam1=8554」**双栈**，非统一 8554 双路
3. **长期修** 仍须 4A（Milk-V）或 4C（SDK 给 json 加 720p dst）

**Step 4 判定：** ⚠️ 部分完成 — workaround 成立，根因 ISSUE **未收口**。
```

---

## Step 5 — 混合双栈可行性（分时切换）✅ 已完成

**目的：** M2 不能假设 `cam_dual.json` 两路皆 rtsp_server。本步验证 **分时** 下 GC2083（554）与 OV5647（8554）两栈是否各自可用。

**状态：** ✅ 已完成（分时通过；同时双流 → Step 6）

**通过标准：**

1. **5A：** 仅 `camera-test` 运行时，`554/h264` 有画面（GC2083）。
2. **5B：** 停 sample_vi 后启 OV5647 单摄 rtsp，`8554/cam0` 或 `cam1` 有画面（OV5647 路径仍正常）。
3. **5C（可选）：** `rtsp_dual_mixed.sh` 启动后 cam0 仍黑、cam1 有图 → 记录为 **已知限制**，M2 改走混合双栈而非 cam_dual。

```shell
# --- 命令：5A 板上（终端 A，保持运行）---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
sh /mnt/system/usr/bin/camera-test.sh

# --- 命令：5A Mac ---
ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264

# --- 结果：5A Mac ---
有视频画面​

# --- 命令：5B 板上（终端 A Ctrl+C 后）---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
sleep 2
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 20
netstat -ln | grep 8554
grep -iE 'OV5647|Init OK|mismatch' /tmp/rtsp_server.log | tail -10

# --- 命令：5B Mac ---
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果：5B Mac ---
有视频画面​

# --- 结论 ---
通过（5A+5B 分时）；GC2083@554、OV5647@8554/cam0 切换后均可用；同时双流与 cam_dual 未测
```

**Agent 分析：**

```text
**5A ✅：** `camera-test` 运行中，`554/h264` **有画面**（GC2083 / 720p 链复验）。

**5B ✅：** 停 sample_vi → 切 OV5647 ini/PQ → `rtsp_server` + `cam0.json` → `8554/cam0` **有画面**。
- 板上日志（SSH 核对）：`OV5647 ... Init OK`，`dev_num:1`，8554 LISTEN
- 说明：**不是**「用过 GC2083 就坏了」；**分时切换** ini/PQ/进程后 OV5647 rtsp_server 路径仍正常

**5C：** 未执行（`rtsp_dual_mixed.sh` / cam0 黑 + cam1 有图）— 可并入 ISSUE-003，预期 cam0(GC2083) 仍黑

**本步未覆盖（M2 关键缺口）：**
- **同时**跑 `camera-test`(554) + `rtsp_server` OV5647(8554) 两路 ffplay — Step 6
- 两进程是否争用 MMF/VI 全局锁，需实测

**产品 URL 映射（分时 / 混合双栈草案）：**

| 镜头 | 程序 | URL（当前验证） |
|------|------|----------------|
| J1 GC2083 | camera-test | `rtsp://192.168.42.1:554/h264` |
| J2 OV5647 | rtsp_server | `rtsp://192.168.42.1:8554/cam0`（单摄 json） |

注：形态三目标仍是统一 `8554/cam0`+`cam1`；上表为 **ISSUE-002 收口后的过渡架构**。

**Step 5 判定：** ✅ 通过（分时双栈可行）。
```

---

## Step 6 — 同时双流（混合双栈）❌ 未通过

**目的：** Step 5 只证明 **切换后** 两路各自可用。M2 需要 **同一时刻** Mac 上两路 ffplay 都有画面。

**状态：** ✅ 已完成（未通过）

**通过标准：**

1. 终端 A：`camera-test`（GC2083）持续运行，554 LISTEN。
2. 终端 B：**不杀** A 的情况下启 OV5647 `rtsp_server`（若失败记日志，说明 MMF 互斥）。
3. Mac **同时**：`554/h264` 与 `8554/cam0` 均有画面 ≥ 30s。

```shell
# --- 命令：终端 A 板上（保持运行）---
for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do kill $_p; done
rm -f /tmp/rtsp_server.pid
sleep 2
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
sh /mnt/system/usr/bin/camera-test.sh

# --- 命令：终端 B 板上（A 仍在跑）---
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 20
netstat -ln | grep -E '554|8554'
tail -15 /tmp/rtsp_server.log

# --- 命令：Mac（两路同时，各开一窗口）---
ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果：Mac ---
554/h264：Connection refused
8554/cam0：无画面
两个同时开似乎有干扰

# --- 结论 ---
未通过；同时跑 sample_vi + rtsp_server 两路皆不可用
```

**Agent 分析：**

```text
**板上实锤（SSH，Step 6 后状态）：**
- 两进程并存：`sample_vi_fd` + `rtsp_server`（OV5647 ini）均存活
- `netstat`：**仅 8554 LISTEN**；**554 未监听** → Mac `554/h264` Connection refused 原因明确
- `rtsp_server` 日志：`OV5647 Init OK` 后连续 `CVI_VENC_GetStream failed with 0xc0078012!` → VENC **取不到码流**（MMF/VI 已被 sample_vi 占用或池冲突）
- Step 5B 单独跑 OV5647 @8554 **有画面**；Step 6 同时跑则 **8554 也无画面** → 干扰是 **双向** 的

**根因判定：**
- SG2000 MMF **不支持** `sample_vi_fd` 与 `rtsp_server` **并行**各占一路传感器出流
- 「cam0=554 + cam1=8554」混合双栈在 **同时** 预览场景 **不可行**
- M2 唯一剩馀软件路径（在修 GC2083@rtsp_server 之前）：**单进程 `rtsp_server` + `cam_dual.json`**（`dev_num=2`），但 ISSUE-002 已证 cam0(GC2083) 仍黑

**架构决策表（ISSUE-002 收官）：**

| 方案 | 同时双流 | 状态 |
|------|----------|------|
| 分时：先 GC2083@554 再 OV5647@8554 | ❌ 非 M2 | Step 5 ✅ |
| 混合：camera-test + rtsp_server 并行 | ❌ | Step 6 ❌ |
| 统一 rtsp_server `cam_dual` @8554 | 理论可 | cam0 黑（未修） |
| GC2083 修好后 rtsp_server 1080p/720p | 目标 | 4A/4C |

**Step 6 判定：** ❌ 未通过。ISSUE-003（M2）须以 **`rtsp_dual_mixed` 单栈** 或 **先解决 ISSUE-002 根因** 为入口，不能再押混合双栈。
```

---

## ISSUE-002 收口（2026-07-01，Step 6 后定稿）

```text
**状态：** ⚠️ **部分收口**（2026-07-01）— 根因与边界已清晰；rtsp_server GC2083@8554 **未修复**

**根因：** GC2083 在 rtsp_server **1080p** 链近黑 YUV；sample_vi **720p** 链正常。已排除：端口、json、venc-bind-vpss、PQ。

**已验证：**
| 场景 | 结果 |
|------|------|
| GC2083 @ `554/h264`（camera-test，单独） | ✅ 有画面 |
| OV5647 @ `8554/cam0`（rtsp_server，单独） | ✅ 有画面 |
| 分时切换（Step 5） | ✅ |
| **同时** camera-test + rtsp_server（Step 6） | ❌ MMF 互斥 |
| GC2083 @ `8554/cam0`（rtsp_server） | ❌ 无画面 |

**对形态三：**
- M1 严格（GC2083@8554）❌
- M2 混合双栈 ❌；须 **单 rtsp_server 双摄** 或 **先修 GC2083**
- 过渡：仅能 **单路** 预览（554 或 8554），不能两路同时

**ISSUE-003 入口建议：**
1. 跑 `rtsp_dual_mixed.sh`，确认 cam1(OV5647) 有图、cam0(GC2083) 仍黑
2. 并行 4A 问 Milk-V / 4C SDK 720p json

**可用方案归档：** [CAMERA_BRINGUP_ARCHIVE.md](../CAMERA_BRINGUP_ARCHIVE.md)（两路分别可跑通的权威配方，2026-07-01）
```

---

## 变更记录

| 日期       | 变更                                                       |
| ---------- | ---------------------------------------------------------- |
| 2026-07-01 | 归档 [CAMERA_BRINGUP_ARCHIVE.md](../CAMERA_BRINGUP_ARCHIVE.md)；新增 preview_gc2083_554.sh |
| 2026-07-01 | Step 5 分时双栈通过；展开 Step 6 |
| 2026-07-01 | Step 1 执行：bVencBindVpss=0 但未出图；展开 Step 2         |
| 2026-06-30 | 自 ISSUE-001 收口创建；展开 Step 1（venc-bind-vpss false） |