# AI — EdgeEye Lite 本地智能（单摄人检测）

当前阶段见 [docs/PRODUCT_LITE_AI.md](../../docs/PRODUCT_LITE_AI.md)。

## 步骤 2：`ai_event_log`（本目录已实现）

无模型，只负责 **本地事件日志**（NDJSON）。

```bash
# 交叉编译（Docker 内）
source scripts/envsetup.sh && make app

# 板上
./ai_event_log --dry-run
./ai_event_log --inject person --score 0.91
tail -1 /mnt/sd/events/events.ndjson   # 或 /mnt/data/events/
```

一行示例：

```json
{"ts":1710000000,"class":"person","score":0.9100,"source":"inject","cam":"cam0"}
```

后续：`ai_grab_frame` → `ai_person_detect.sh --once|--watch`（可选 `--record`）→ `ai_event_log` / `record_clip.sh`；`ai=1` 时由 `run_edgeeye_stack.sh` 拉起。

默认偏保守（`ai_interval_sec=20`、`ai_record=0`），减轻与 RTSP 预览抢流。
