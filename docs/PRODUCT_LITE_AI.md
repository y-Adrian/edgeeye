# EdgeEye Lite + AI 路线（单摄 GC2083）

## 产品约定

| 项 | 选择 |
|----|------|
| 镜头 | **GC2083**（J1 / cam0） |
| AI | **仅人检测** |
| 通知 | 第一阶段 **仅本地日志**（不做推送） |
| 双摄 / 网页 HLS | 非默认；开发用时再开 |

默认 conf 见 `configs/edgeeye_cam.conf`（`mode=gc2083`，`web=0`）。

## 分步实现（每步单独提交 + 板上验证）

| 步骤 | 内容 | 状态 |
|------|------|------|
| 1 | 单摄 GC2083 产品基线（默认 conf / 文档） | ✅ |
| 2 | AI 事件本地日志骨架（`apps/ai/ai_event_log`，无模型） | ✅ |
| 3 | AI 取帧通路（`apps/ai/ai_grab_frame`，RTSP→JPEG） | ✅ |
| 4 | 板端人检测（`ai_person_detect.sh` + MobileDet pedestrian）→ 写日志 | ✅ |
| 5 | 检测触发录像（`ai_person_detect.sh --record`） | ✅ |
| 6 | 循环检测 + cooldown（`--watch`）；`ai=1` 接入产品栈 | ✅ |
| 7 | VPSS 按需直取 AI 帧，去掉第二个 RTSP 客户端/H.264 解码 | ✅ |

### 步骤 2 用法

```bash
./ai_event_log --dry-run
./ai_event_log --inject person --score 0.91
tail -1 /mnt/sd/events/events.ndjson
./scripts/check_ai_event_log_board.sh   # Mac 远程验
```

### 步骤 3 用法

```bash
# 需 edgeeye_cam 已推 cam0
./ai_grab_frame --dry-run
./ai_grab_frame --once                    # 默认 448x448 → /tmp/edgeeye_ai_frame.jpg
./scripts/check_ai_grab_frame_board.sh
```

默认分辨率 **448×448**，对齐板上 `mobiledetv2-pedestrian-*-448.cvimodel`。

### 步骤 4 用法

```bash
# 宿主机一次（缺 libcvi_tdl_app.so 时）
./scripts/install_tdl_libs_board.sh

# 板上（需 cam0 RTSP）
./ai_person_detect.sh --dry-run
./ai_person_detect.sh --once
# 有人时写入 events.ndjson，source=detect
./scripts/check_ai_person_detect_board.sh
```

可与 `edgeeye_cam` 同时运行（JPEG 检测，不抢 VI）。

### 步骤 5 用法

```bash
# 检测到人时额外录一段 cam0（默认 15s）
./ai_person_detect.sh --once --record --clip-sec 15
# 无人画面可用 --simulate-person 验录像通路
# ./ai_person_detect.sh --once --simulate-person --record --clip-sec 8
ls /mnt/sd/clips/   # 或 /mnt/data/clips/

./scripts/check_ai_person_record_board.sh
```

### 步骤 6 用法

```bash
# 循环：无人按 interval 轮询；检出后写日志并 cooldown
# 默认 interval=20、栈上 ai_record=0，减轻与 RTSP 预览抢流导致的越跑越卡
./ai_person_detect.sh --watch --interval 20 --cooldown 60
# 需要检出录像时再加：--record（或 conf ai_record=1）

# 有限轮次（验收）
./ai_person_detect.sh --watch --max-rounds 2 --interval 1

# 产品栈：edgeeye_cam.conf 设 ai=1，再
# ./stop_edgeeye_stack.sh && ./run_edgeeye_stack.sh
# 后台 pid：/tmp/ai_person_detect.pid

./scripts/check_ai_person_watch_board.sh
```

### 旧版 RTSP 取帧的预览卡顿

步骤 6 及更早版本通过同一路 RTSP 取帧；轮询过密或检出后 ffmpeg 录像会拖垮 ISP/VENC。步骤 7 改为 VPSS 按需直取；使用 `ai_frame_source=rtsp` 回退时仍建议：

| 项 | 默认 | 说明 |
|----|------|------|
| `ai_interval_sec` | **20** | 少抢流 |
| `ai_record` | **0** | 只写事件日志，不自动录像 |
| 盯画面调试 | 临时 `ai=0` | 或只用 `./ai_person_detect.sh --once` |

需要「检出就录像」时再设 `ai_record=1`，并建议 `ai_interval_sec≥15`。

### 步骤 7 用法

```bash
# 产品栈 ai=1 且 ai_frame_source=vpss 时自动给 edgeeye_cam 加 --ai-direct
./stop_edgeeye_stack.sh && ./run_edgeeye_stack.sh

# 手工验证一次 VPSS 直取（不连接 rtsp://...）
./ai_grab_frame --once --source vpss

# Mac 侧板上验收
./scripts/check_ai_direct_frame_board.sh
```

流程变为：

```text
VPSS ch0 --按请求短暂 Get/Release--> NV12 --本地 scale/JPEG--> MobileDet
     └---------------------------> VENC/RTSP 预览
```

`ai_frame_source=rtsp` 保留为兼容/回退路径。

板上验收结果：连续 3 次 VPSS 取帧后，cam0 在 3 秒内仍输出 **84 帧（1280×720）**；MobileDet 能读取直取生成的 448×448 JPEG。

## 板上已具备的 AI 资产（摸底）

- 驱动：`cv181x_tpu`
- 库：`/mnt/system/lib/libcvi_tdl.so`
- 样例：`/mnt/system/usr/bin/ai/sample_yolov*`
- 行人相关模型示例：`/mnt/cvimodel/mobiledetv2-pedestrian-d0-ls-448.cvimodel`

具体封装以步骤 4 实测为准。

## 观看（Lite）

```text
rtsp://<板子IP>:8554/cam0
```

同网 IP 见 `ip -4 addr show wlan0` 或 USB `192.168.42.1`。
