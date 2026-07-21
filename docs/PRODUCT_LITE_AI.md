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
| 3 | AI 取帧通路（低分辨率帧供检测） | 待做 |
| 4 | 板端人检测（TPU / `mobiledet` 行人模型等）→ 写日志 | 待做 |
| 5 | （可选）检测触发录像，与 `motion_recorder` 衔接 | 待做 |

### 步骤 2 用法

```bash
./ai_event_log --dry-run
./ai_event_log --inject person --score 0.91
tail -1 /mnt/sd/events/events.ndjson
./scripts/check_ai_event_log_board.sh   # Mac 远程验
```

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
