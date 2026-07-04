# EdgeEye 上手指南

## 这是什么

面向 **Milk-V Duo S** 的双摄 RTSP 产品：J1 GC2083 + J2 OV5647，本地推流，可选 Web 快照与动检录像。

## 当前能力

| 功能 | 状态 |
|------|------|
| 单摄 / 双摄 RTSP @8554 | ✅ `edgeeye_cam` |
| 1080p / 720p / 480p | ✅ |
| 配置文件 + 开机自启 | ✅ |
| Web 快照页 | ✅（需 ffmpeg） |
| 动检录像 | 可选（`record=1`） |
| 浏览器 RTSP 直播 | 未做（用 ffplay/VLC） |

## 开发环境

**第一次搭环境请读：[DEVELOPMENT.md](./DEVELOPMENT.md)**（**§0 版本与基线**：SDK commit、板型、工具链、Docker 镜像）

要点：

1. Mac 装 Docker + `brew install ffmpeg`；同级准备 `duo-sdk`（`duo-buildroot-sdk-v2`，推荐 `e7fefaa9f`）
2. 启动容器并挂载工作区（见 DEVELOPMENT.md §4）
3. 容器内 `cd edgeeye-duos && source scripts/envsetup.sh`
4. `make app && ./deploy`

## 五分钟上手

```bash
# 1. Docker 内（已 source scripts/envsetup.sh）
cd edgeeye-duos && source scripts/envsetup.sh && make app && ./deploy

# 2. 板上
ssh root@192.168.42.1
./run_edgeeye_stack.sh
./health_check.sh

# 3. Mac
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
```

双摄若 VPSS/ION 失败：**reboot** 后再 `./run_edgeeye_stack.sh`。

## 关键文件

| 路径 | 作用 |
|------|------|
| `/root/edgeeye_cam` | RTSP 主程序 |
| `/root/edgeeye_cam.conf` | 模式/端口/分辨率/Web |
| `/root/run_edgeeye_stack.sh` | 启动 RTSP + Web + 录像 |
| `/tmp/edgeeye_cam_rtsp.log` | 推流日志 |

## 下一步读什么

1. [DEVELOPMENT.md](./DEVELOPMENT.md) — 开发环境完整配置
2. [HOME_USER_GUIDE.md](./HOME_USER_GUIDE.md) — 家用配置
3. [DEPLOYMENT.md](./DEPLOYMENT.md) — ffmpeg、自启、架构
4. [apps/camera/README.md](../apps/camera/README.md) — 改 edgeeye_cam 源码
