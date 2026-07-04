# EdgeEye Duo S

Milk-V Duo S 边缘双摄 RTSP 产品：`edgeeye_cam` 单摄/双摄直播，可选 Web 快照页与动检录像。

## 能力

- **双摄 RTSP**：`rtsp://192.168.42.1:8554/cam0`（GC2083）+ `cam1`（OV5647）
- **分辨率档位**：1080p / 720p / 480p
- **开机自启**：`edgeeye_cam.conf` + `install_autostart.sh`
- **Web 快照页**：`http://192.168.42.1:8080/`（需板载 ffmpeg）
- **动检录像**（可选）：`debris.ko` + `motion_recorder` + ffmpeg

## 目录

```text
edgeeye-duos/
├── apps/camera/      edgeeye_cam 源码
├── apps/motion/      motion_recorder 等
├── configs/          edgeeye_cam.conf、sensor ini
├── scripts/          板上运行脚本
├── tests/camera/     my_cam_test 验收
├── web/              浏览器快照页
├── board/driver/     可选 debris.ko
├── deploy            上传到板子
└── docs/             部署与硬件说明
```

## 构建与部署

完整开发环境（Docker、工具链、Mac/板子连接）见 **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**。

Docker 内（先 `source /home/work/init_env.sh`）：

```bash
cd /home/work/edgeeye-duos
make app && ./deploy
```

仅驱动：`make driver`。全量：`make`。

## 板上快速开始

```bash
# 编辑配置
vi /root/edgeeye_cam.conf

# 启动完整栈（RTSP + Web + 可选录像）
./run_edgeeye_stack.sh

# 开机自启
./install_autostart.sh && reboot

# 健康检查
./health_check.sh
```

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
