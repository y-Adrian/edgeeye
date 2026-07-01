# ISSUE-002: GC2083 rtsp_server 8554 1080p 空流（继承 ISSUE-001）

**状态：** 🔄 进行中（Step 1 ⏳ 待执行）

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
- OV5647 同栈 8554 ~4 Mbps ✅ → 问题 **GC2083 + rtsp_server 管线特化**

---

## Step 1 — `venc-bind-vpss: false` + `vi-vpss-mode: 0` ⏳ 待执行

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


# --- 命令：Mac ---
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 15 gc2083_step1.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083_step1.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0

# --- 结果：Mac ---


# --- 结论 ---
（通过 / 未通过；bit_rate；有无画面；bVpssBinding 是否变为 0）
```

**Agent 分析：**

```text
（留空）
```

---

## Step 2 — 预留：对照原厂最小 json / Milk-V 支持 ⏳ 预留

**目的：** Step 1 未通过时，用 `duo-sdk/cvi_rtsp/test/h264.json` 最小配置或向 Milk-V 索取 GC2083 官方 `cam0.json`。

**状态：** 🟡 Step 1 完成后再展开

---

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-06-30 | 自 ISSUE-001 收口创建；展开 Step 1（venc-bind-vpss false） |
