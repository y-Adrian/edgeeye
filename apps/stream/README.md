# RTSP streaming (Phase 5A MVP)

本目录只保留 **板上启动脚本**；JSON / sensor ini 的权威副本在 `configs/`。

| 配置（源） | 板上路径（`make` + `./deploy` 后） |
|------------|-------------------------------------|
| `configs/stream/cam0.json` | `/root/stream/cam0.json` |
| `configs/stream/cam_dual.json` | `/root/stream/cam_dual.json` |
| `configs/sensor/*.ini` | `/root/stream/*.ini`（脚本再链到 `/mnt/data/`） |

## URLs

| Config | URL |
|--------|-----|
| `cam0.json` | `rtsp://192.168.42.1:8554/cam0` |
| `cam_dual.json` | `cam0` + `cam1`（需 `sensor_cfg.ini` `dev_num=2`） |

## Build & deploy

```bash
# Docker 内
source /home/work/init_env.sh
cd /home/work/edgeeye-duos
make && ./deploy

ssh root@192.168.42.1
/root/stream/start_rtsp.sh
```

## Scripts（本目录）

| File | Role |
|------|------|
| `start_rtsp.sh` / `stop_rtsp.sh` | 启停 vendor `rtsp_server` |

混搭双摄：`scripts/setup_mixed_dual_camera.sh`。详见 `rtsp_notes.md`、`docs/MVP_MEDIA_PIPELINE.md`。
