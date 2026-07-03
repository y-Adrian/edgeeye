# Deployment Guide

## Build (Docker)

```bash
docker run --privileged --platform linux/amd64 -it \
  -v /Users/debris/Documents/learn/riscv:/home/work \
  milkvtech/milkv-duo:latest /bin/bash

source /home/work/duo-sdk/init_env.sh
cd /home/work/Camera && make
```

## Deploy to board

```bash
./deploy
ssh root@192.168.42.1
chmod +x /root/*.sh /root/stream/*.sh
```

## Vendor media prerequisites

```bash
ls /mnt/system/usr/test/rtsp_server
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
```

If `rtsp_server` missing: `build_middleware && build_cvi_rtsp` in SDK.

## Autostart (edgeeye_cam)

```bash
# 编辑配置（mode / port / res）
vi /root/edgeeye_cam.conf

# 安装开机自启
./install_autostart.sh
/etc/init.d/S99edgeeye_cam start

# 验证
./health_check.sh
reboot   # 插电后 Mac 直接 ffplay，无需 SSH
```

Legacy security stack: `./install_autostart.sh security`

## Architecture (edgeeye_cam)

```
GC2083 (J1) + OV5647 (J2)
        |
   edgeeye_cam (VI/ISP/VPSS/VENC)
        |
   RTSP :8554/cam0 + cam1
        |
   Mac ffplay / ffmpeg
```

Config: `/root/edgeeye_cam.conf` — see `configs/edgeeye_cam.conf`.

## Architecture (legacy run_security)

```
OV5647 --I2C--> debris.ko (sensor init, GPIO motion)
                    |
                    v
         vendor VI/VPSS/VENC --> rtsp_server --> RTSP :8554/cam0
                    |
         motion_recorder <-- EPOLLPRI ioctl
                    |
              ffmpeg -c copy --> /mnt/sd/clips/*.mp4
```

Dual camera adds second sensor (J1) + `cam_dual.json` + `sensor_cfg_OV5647_dual.ini`.

**This board (2026-06):** J1 = GC2083 (`i2c-3/0x37`), J2 = OV5647 (`i2c-2/0x36`) — not two OV5647s.
See [CAMERA_VERIFY.md](./CAMERA_VERIFY.md) for mapping, PQ bin notes, and step-by-step checks.

## RTSP preview and recording (PC)

Stock Milk-V rootfs does **not** include `ffplay` or `ffmpeg`. Use your PC:

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 30 clip.mp4
```

Optional on-board ffmpeg: copy a static `riscv64` binary to `/mnt/data/bin/ffmpeg`, then
`./record_clip.sh 10 cam0` works locally.

### SDK `build_3rd_party` 说明

预编译 `ffmpeg.tar.gz` **只有** `libav*` 库 + `ffprobe`，**没有** `ffmpeg`/`ffplay` 可执行文件。

```bash
# Docker 内查看
tar -tzf duo-sdk/install/.../third_party/ffmpeg.tar.gz | grep '^bin/'
# → bin/ffprobe  （仅此一个）

# 仅装 ffprobe（改善 health_check RTSP 探测）
cd Camera && chmod +x scripts/install_ffprobe_board.sh
./scripts/install_ffprobe_board.sh

# 板上本地录像：交叉编译静态 ffmpeg
chmod +x scripts/build_ffmpeg_cli.sh scripts/install_ffmpeg_cli_board.sh
./scripts/build_ffmpeg_cli.sh          # 约 10–20 分钟
./scripts/install_ffmpeg_cli_board.sh
```

## Test fixes (TC-22)

If `test_debris` fails on `i2c_adapter` vs `i2c_adapter_dt`, rebuild `test_debris` from
latest sources — `parse_proc_val` now requires exact proc key names.
