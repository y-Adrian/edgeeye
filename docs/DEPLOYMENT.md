# 部署与运行

开发环境（Docker、工具链、Mac 连接板子）见 **[DEVELOPMENT.md](./DEVELOPMENT.md)**。本文侧重板上运行、ffmpeg 与架构说明。

## 快速部署

```bash
# Docker 内
cd edgeeye-duos && source scripts/envsetup.sh
make app && ./deploy

ssh root@192.168.42.1
chmod +x /root/*.sh
./run_edgeeye_stack.sh
./health_check.sh
```

## 开机自启

```bash
vi /root/edgeeye_cam.conf
./install_autostart.sh
/etc/init.d/S99edgeeye_cam start
reboot
```

## 架构

```text
GC2083 (J1) + OV5647 (J2)
        |
   edgeeye_cam (VI/ISP/VPSS/VENC)
        |
   RTSP :8554/cam0 + cam1
        |
   Mac ffplay / 板载 ffmpeg（快照/录像）
```

| 配置 | 路径 |
|------|------|
| 运行配置 | `/root/edgeeye_cam.conf`（模板 `configs/edgeeye_cam.conf`） |
| 混搭双摄 ini | `configs/sensor/sensor_cfg_GC2083_OV5647_dual.ini` → deploy 到 `/root/stream/`，启动时链到 `/mnt/data/sensor_cfg.ini` |

**硬件：** J1 = GC2083（I2C3 @0x37），J2 = OV5647（I2C2 @0x36）。详见 [HARDWARE_NOTES.md](./HARDWARE_NOTES.md)。

## RTSP preview (PC)

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 30 clip.mp4
```

Mac 一键：`./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both --start-board`

## Board ffmpeg (snapshots / recording)

Stock rootfs has no `ffmpeg` CLI. Cross-compile in Docker:

```bash
source scripts/envsetup.sh
./scripts/build_ffmpeg_cli.sh          # 约 10–20 分钟
./scripts/install_ffmpeg_cli_board.sh
```

**`rev8` / `.option arch,+zbb` 编译失败**：Duo S 工具链不支持 RISC-V Zbb，`build_ffmpeg_cli.sh` 已加 `--disable-asm --disable-rvv`。

可选：`./scripts/install_ffprobe_board.sh` 改善 `health_check` RTSP 探测。

## Dual-camera tips

- 单摄切双摄失败时：**reboot** 后再 `./run_edgeeye_stack.sh`
- 卡顿时设 `res=480p`，或 `web=0` 关闭快照（避免 ffmpeg 抢 RTSP）
