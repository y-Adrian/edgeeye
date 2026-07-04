# EdgeEye Project Status

## 产品目标

Milk-V Duo S 双摄边缘节点：本地 RTSP 直播，可选 Web 快照、动检录像，后续接入本地 AI。

## 当前状态（2026-07）

环境基线（SDK / 工具链 / Docker）见 [DEVELOPMENT.md §0](./DEVELOPMENT.md#0-版本与基线)。

### 已完成

- **`edgeeye_cam`**：单摄/双摄 CLI，`--res` 三档分辨率
- **双摄 RTSP 同时出图**（GC2083 cam0 + OV5647 cam1 @8554）
- **产品栈**：`run_edgeeye_stack.sh`（RTSP + Web + 可选录像）
- **开机自启**：`edgeeye_cam.conf` + `install_autostart.sh`
- **健康检查 / 长稳**：`health_check.sh`、`stability_6h.sh`
- **Mac 预览**：`preview_my_cam_rtsp_mac.sh`
- **板载 ffmpeg 交叉编译**：Web 快照、本地录像

### 待做

- HLS/WebRTC 浏览器低延迟直播
- YOLO / 本地通知
- 6h 长稳正式收口

## 常用命令

开发环境配置见 [DEVELOPMENT.md](./DEVELOPMENT.md)。

```bash
make app && ./deploy
./run_edgeeye_stack.sh
./install_autostart.sh && reboot
./health_check.sh
```

## 配置

`/root/edgeeye_cam.conf`（模板 `configs/edgeeye_cam.conf`）：

```ini
mode=dual
port=8554
res=720p
web=1
record=0
```
