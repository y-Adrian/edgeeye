# EdgeEye Project Status

## 产品目标

Milk-V Duo S **EdgeEye Lite**：单摄 **GC2083** 边缘节点；本地 RTSP + 可选动检录像；后续 **人检测 AI → 本地事件日志**（见 [PRODUCT_LITE_AI.md](./PRODUCT_LITE_AI.md)）。双摄/HLS 保留为开发选项。

## 当前状态（2026-07）

环境基线（SDK / 工具链 / Docker）见 [DEVELOPMENT.md §0](./DEVELOPMENT.md#0-版本与基线)。

### 已完成

- **`edgeeye_cam`**：单摄/双摄 CLI，`--res` 三档分辨率
- **双摄 RTSP**（开发用：GC2083 + OV5647 @8554）
- **产品默认**：`mode=gc2083`（Lite 单摄 cam0）
- **产品栈**：`run_edgeeye_stack.sh`（RTSP + 可选 Web + 可选录像）
- **开机自启** / **健康检查** / **Mac 预览**
- **板载 ffmpeg**（录像 / 动检 / 可选 HLS）
- **WiFi 配置与检查**（[WIFI.md](./WIFI.md)）

### 进行中 / 待做

- Lite + AI：人检测 → 本地日志（分步见 PRODUCT_LITE_AI.md）
- TPU 推理接入
- 6h 长稳正式收口
- WebRTC（可选）

## 常用命令

开发环境配置见 [DEVELOPMENT.md](./DEVELOPMENT.md)。

```bash
make app && ./deploy
./run_edgeeye_stack.sh
./health_check.sh
```

## 配置

`/root/edgeeye_cam.conf`（模板 `configs/edgeeye_cam.conf`）：

```ini
mode=gc2083
port=8554
res=720p
web=0
record=0
```
