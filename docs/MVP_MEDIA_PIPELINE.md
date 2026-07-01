# MVP Media Pipeline Notes

Phase 5A goal: **dual-camera capture → encode → RTSP preview** using vendor BSP first,
with `debris.ko` handling sensor I2C bring-up and motion/GPIO events.

## Current state (board snapshot)

| Component | Status |
|-----------|--------|
| OV5647 I2C @ i2c-2/0x36 | Verified via `debris.ko` + `i2ctransfer` |
| `debris.ko` sensor init | Chip ID, reset, 640x480 reg table |
| Vendor modules | Often loaded: `cvi_mipi_rx`, `cv181x_vi`, `snsr_i2c`, … |
| `/dev/video*` | Usually **absent** until vendor pipeline/sample starts |

## Recommended bring-up order

1. Load `debris.ko` — sensor control + `/proc/debris` stats
2. Run `scripts/check_vendor_media.sh` on board — document module/video node state
3. Start vendor sample (see `duo-sdk/cvi_mpi/sample/`, `tdl_sdk/sample_video/`)
4. Re-run check script — confirm `/dev/video0` (and optionally `/dev/video1`)
5. User-space RTSP MVP (`app/stream/`) on top of vendor VENC/RTSP APIs

## RTSP MVP (`apps/stream`)

```bash
make && ./deploy
ssh root@192.168.42.1 './stream/start_rtsp.sh'
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
```

Config: `output/stream/cam0.json` → vendor `/mnt/system/usr/test/rtsp_server`.

Full stack: `./run_security.sh` starts debris + motion + RTSP + motion_recorder + health_check.

## Motion-triggered recording

`motion_recorder` listens for `DEBRIS_GET_MOTION` (EPOLLPRI on `/dev/debris_kernel`), then:

```bash
ffmpeg -rtsp_transport tcp -i rtsp://127.0.0.1:8554/cam0 -c copy -t 30 clip.mp4
```

Clips: `/mnt/sd/clips/` (fallback `/mnt/data/clips/`). Manual test: `./record_clip.sh 10 cam0`.

## Dual camera

- INI: `app/stream/sensor_cfg_OV5647_dual.ini` (`dev_num=2`, J1+J2)
- JSON: `cam_dual.json` → `rtsp://…:8554/cam0` and `cam1`
- Setup: `./setup_dual_camera.sh` or `DEBRIS_DUAL=1 ./run_security.sh`

```bash
# Host → board
ssh root@192.168.42.1 'sh -s' < scripts/check_vendor_media.sh

# After debris load
insmod /root/debris.ko register_fallback_pdev=0
cat /proc/debris
```

## Dual camera

- DT: `debris,camera-count`, optional `debris,cam1-*` in `dts/debris-camera-engine.dtsi`
- Hardware: confirm second CSI port + I2C bus in `RESOURCES.md` / `HARDWARE_NOTES.md`
- MVP: single RTSP stream first, then `cam1` when BSP supports concurrent VI

## References

- `duo-sdk/linux_5.10/drivers/media/i2c/ov5647.c`
- `duo-sdk/cvi_mpi/sample/venc/`
- `duo-sdk/cvi_rtsp/`
- `ROADMAP.md` Phase 5A / 6
