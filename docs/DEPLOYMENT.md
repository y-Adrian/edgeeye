# Deployment Guide

## Build (Docker)

```bash
docker run --privileged --platform linux/amd64 -it \
  -v /Users/debris/Documents/learn/riscv:/home/work \
  milkvtech/milkv-duo:latest /bin/bash

source /home/work/init_env.sh
cd /home/work/edgeeye-duos && make app
```

## Deploy to board

```bash
./deploy
ssh root@192.168.42.1
chmod +x /root/*.sh
```

## Autostart

```bash
vi /root/edgeeye_cam.conf
./install_autostart.sh
/etc/init.d/S99edgeeye_cam start
./health_check.sh
reboot
```

## Architecture

```text
GC2083 (J1) + OV5647 (J2)
        |
   edgeeye_cam (VI/ISP/VPSS/VENC)
        |
   RTSP :8554/cam0 + cam1
        |
   Mac ffplay / 板载 ffmpeg（快照/录像）
```

Config: `/root/edgeeye_cam.conf` — see `configs/edgeeye_cam.conf`.

Sensor ini: `configs/sensor/sensor_cfg_GC2083_OV5647_dual.ini` → deploy 到 `/root/stream/`，启动时链到 `/mnt/data/sensor_cfg.ini`。

**硬件：** J1 = GC2083（I2C3 @0x37），J2 = OV5647（I2C2 @0x36）。详见 [HARDWARE_NOTES.md](./HARDWARE_NOTES.md)。

## RTSP preview (PC)

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 30 clip.mp4
```

## Board ffmpeg (snapshots / recording)

Stock rootfs has no `ffmpeg` CLI. Cross-compile:

```bash
source /home/work/init_env.sh
cd /home/work/edgeeye-duos
./scripts/build_ffmpeg_cli.sh          # 约 10–20 分钟
./scripts/install_ffmpeg_cli_board.sh
```

**`rev8` / `.option arch,+zbb` 编译失败**：Duo S 工具链不支持 Zbb，`build_ffmpeg_cli.sh` 已加 `--disable-asm --disable-rvv`。

Optional: `./scripts/install_ffprobe_board.sh` for richer `health_check` RTSP probes.

## Dual-camera tips

- 单摄切双摄失败时：**reboot** 后再 `./run_edgeeye_stack.sh`
- 卡顿时可设 `res=480p`，或暂时 `web=0` 关闭快照（避免 ffmpeg 抢 RTSP）
