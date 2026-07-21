# EdgeEye Duo S

Milk-V Duo S 边缘双摄 RTSP 产品：`edgeeye_cam` 单摄/双摄直播，可选浏览器 HLS / 快照页与动检录像。

## 能力

- **双摄 RTSP**：`rtsp://192.168.42.1:8554/cam0`（GC2083）+ `cam1`（OV5647）
- **分辨率档位**：1080p / 720p / 480p
- **开机自启**：`edgeeye_cam.conf` + `install_autostart.sh`
- **浏览器双路直播**：`web=1` + `web_live=hls` → `http://192.168.42.1:8080/`（ffmpeg remux；可选 `snapshot`）
- **动检录像**（可选）：`record=1`，默认只探/录 cam0；GPIO/PIR 可用 `motion_source=debris`

## 目录

```text
edgeeye-duos/
├── apps/camera/      edgeeye_cam 源码
├── apps/motion/      motion_recorder 等
├── configs/          edgeeye_cam.conf、sensor ini
├── scripts/          板上运行脚本
├── tests/camera/     my_cam_test 验收
├── web/              浏览器 HLS / 快照页（含 vendor/hls.min.js）
├── board/driver/     可选 debris.ko
├── deploy            上传到板子
└── docs/             部署与硬件说明
```

## 构建与部署

完整开发环境（Docker、SDK 版本、工具链、Mac/板子连接）见 **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**（含 **§0 版本与基线**）。

环境基线摘要：

| 项 | 值 |
|----|-----|
| 板型 | Milk-V Duo S（SG2000 / C906） |
| SDK | [duo-buildroot-sdk-v2](https://github.com/milkv-duo/duo-buildroot-sdk-v2)，板型 `milkv-duos-musl-riscv64-sd` |
| 工具链 | `riscv64-unknown-linux-musl-gcc` 10.2.0 |
| Docker | `milkvtech/milkv-duo:latest`（`linux/amd64`） |

Docker 内（先 `source scripts/envsetup.sh`，见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)）：

```bash
cd edgeeye-duos          # 容器内路径取决于挂载，见 DEVELOPMENT.md
source scripts/envsetup.sh
make app && ./deploy
```

仅驱动：`make driver`。全量：`make`。

## 板上快速开始

编辑 `/root/edgeeye_cam.conf` 按需开关（默认 **web=0 record=0 autostart=0**）：

```bash
vi /root/edgeeye_cam.conf
./run_edgeeye_stack.sh          # 手动启动 RTSP 栈
./install_autostart.sh status   # 查看自启状态
```

| 想要 | conf 设置 |
|------|-----------|
| 仅 RTSP | `web=0 record=0 autostart=0`，手动 `./run_edgeeye_stack.sh` |
| + 浏览器双路 HLS | `web=1` `web_live=hls` `record=0`，重启栈 |
| + JPEG 慢刷 | `web=1` `web_live=snapshot`，重启栈 |
| + 动检录像 | `record=1`（默认 cam0），重启栈；勿与 HLS 同时大开 |
| 上电自启 | `autostart=1`，`./install_autostart.sh` |

Mac 预览：

```bash
./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both
# 或
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
```

## 文档

| 文档 | 内容 |
|------|------|
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | **开发环境**（Docker、工具链、部署、Mac 调试） |
| [docs/ONBOARDING.md](docs/ONBOARDING.md) | 新手上手 |
| [docs/HOME_USER_GUIDE.md](docs/HOME_USER_GUIDE.md) | 家用说明 |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | 架构、ffmpeg、双摄技巧 |
| [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) | 当前进度 |
| [docs/HARDWARE_NOTES.md](docs/HARDWARE_NOTES.md) | 板级硬件 |
| [apps/camera/README.md](apps/camera/README.md) | edgeeye_cam 开发 |
| [tests/camera/TESTCASES.md](tests/camera/TESTCASES.md) | 验收用例 |

## 测试

```bash
make test              # 宿主机静态测试
make test-board        # 板上冒烟（须 deploy）
./scripts/test_my_cam_test_suite.sh --profile dual-unified -p 5
```
