# EdgeEye 家用说明

Milk-V Duo S 双摄安防节点 — 插电即用快速指南。

## 两个直播地址

| 镜头 | 接口 | RTSP |
|------|------|------|
| 门口 / J1 GC2083 | cam0 | `rtsp://192.168.42.1:8554/cam0` |
| 室内 / J2 OV5647 | cam1 | `rtsp://192.168.42.1:8554/cam1` |

Mac 预览：

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam1
```

浏览器页（`web=1`，需板载 ffmpeg + python3）：

```text
http://192.168.42.1:8080/
```

- 默认 `web_live=hls`：**双路 HLS 直播**（延迟约数秒）
- `web_live=snapshot`：JPEG 约 3 秒刷新（旧模式）

默认 **web=0** 关闭；设 `web=1` 并重启栈后开启。开 HLS 时建议 `record=0`，避免与动检抢 RTSP。

注意：须用 **http://**，不是 https。

## 功能开关

所有可选功能在 **`/root/edgeeye_cam.conf`** 里控制：

| 配置项 | 含义 | 生效方式 |
|--------|------|----------|
| `web=0` | 关闭浏览器页（默认关） | 重启栈 |
| `web=1` | 开启 `http://192.168.42.1:8080/` | 重启栈 |
| `web_live=hls` | 双路 HLS 直播（默认） | 重启栈 |
| `web_live=snapshot` | JPEG 慢刷 | 重启栈 |
| `record=0` | 关闭动检录像（默认关） | 重启栈 |
| `record=1` | 开启动检录像（仅 cam0） | 重启栈 |
| `autostart=0` | 不开机自启（默认关） | `./install_autostart.sh` |
| `autostart=1` | 上电自动跑 RTSP 栈 | `./install_autostart.sh` |

**RTSP 推流**本身没有单独开关；需要直播时执行 `./run_edgeeye_stack.sh`，不需要时 `./stop_edgeeye_stack.sh`。

### 示例：只要 RTSP，不要 Web / 录像 / 自启

```ini
web=0
record=0
autostart=0
```

```bash
./stop_edgeeye_stack.sh
./run_edgeeye_stack.sh          # 仅 RTSP
./install_autostart.sh          # 确保未装 init.d
```

### 示例：RTSP + Web，但不要自启

```ini
web=1
record=0
autostart=0
```

```bash
./stop_edgeeye_stack.sh && ./run_edgeeye_stack.sh
```

## 配置文件

编辑 `/root/edgeeye_cam.conf`：

```ini
mode=dual          # dual | gc2083 | ov5647
port=8554
res=720p           # 1080p | 720p | 480p
web=0              # 0=关 Web 快照页  1=开
record=0           # 0=关动检录像     1=开
autostart=0        # 0=不开机自启     1=开
```

改 **web / record** 后：

```bash
./stop_edgeeye_stack.sh
./run_edgeeye_stack.sh
```

改 **autostart** 后：

```bash
./install_autostart.sh
```

## 动检录像

默认使用 **RTSP 画面差分**（`motion_source=rtsp`），**无需** PIR 或 `debris.ko`。

1. 确认 SD 卡挂载：`/mnt/sd/clips` 或 `/mnt/data/clips`
2. 板端安装 ffmpeg：`./scripts/build_ffmpeg_cli.sh && ./scripts/install_ffmpeg_cli_board.sh`
3. 编辑 `/root/edgeeye_cam.conf`：

```ini
record=1
motion_source=rtsp      # rtsp | debris | auto
motion_threshold=8000   # 越大越不敏感
motion_interval_sec=2   # 探测间隔
clip_sec=30
cooldown_sec=15
```

4. 重启栈：`./stop_edgeeye_stack.sh && ./run_edgeeye_stack.sh`
5. 录像文件：`clips/<timestamp>_cam0.mp4`（双摄另有 `_cam1.mp4`）

若已接 PIR/按键到 GPIO A20（500），可设 `motion_source=debris` 或 `auto`（需 `debris.ko`）。

手动录一段：

```bash
./record_clip.sh 30 cam0
```

## 开机自启

在 conf 里设 `autostart=1`，再同步 init 脚本：

```bash
vi /root/edgeeye_cam.conf   # autostart=1
./install_autostart.sh
reboot
```

关闭自启：`autostart=0` 后执行 `./install_autostart.sh`（或 `./install_autostart.sh disable`）。

查看状态：`./install_autostart.sh status`

## 健康检查

```bash
./health_check.sh
tail -f /tmp/edgeeye_stack.log
```

## 常见问题

| 现象 | 处理 |
|------|------|
| 双摄第二路黑屏 | `reboot` 后 `./start_my_cam_rtsp.sh dual` |
| 浏览器无快照 | 板端需 ffmpeg；或只用 RTSP |
| 单摄切双摄失败 | reboot 或 `start_my_cam_rtsp.sh dual --reboot` |
| 板子要上外网 | 见 [WIFI.md](./WIFI.md)：`setup_wifi_board.sh` + `check_wifi_board.sh` |

## 日志位置

| 文件 | 内容 |
|------|------|
| `/tmp/edgeeye_stack.log` | 产品栈启动 |
| `/tmp/edgeeye_cam_rtsp.log` | edgeeye_cam 推流 |
| `/tmp/stability_6h.log` | 长稳测试 |
