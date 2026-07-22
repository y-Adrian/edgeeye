# EdgeEye Project Status（2026-07-22）

## 产品目标

Milk-V Duo S **EdgeEye Lite**：单摄 **GC2083** 边缘节点；本地 RTSP + **人体/行人检测** + 本地事件日志，可选检出录像。双摄/HLS 保留为开发选项。

## 当前状态

环境基线（SDK / 工具链 / Docker）见 [DEVELOPMENT.md §0](./DEVELOPMENT.md#0-版本与基线)。

### 已完成

- **`edgeeye_cam`**：单摄/双摄 CLI，`--res` 三档分辨率
- **双摄 RTSP**（开发用：GC2083 + OV5647 @8554）
- **产品默认**：`mode=gc2083`（Lite 单摄 cam0）
- **产品栈**：`run_edgeeye_stack.sh`（RTSP + 可选 Web + 可选录像）
- **开机自启** / **健康检查** / **Mac 预览**
- **板载 ffmpeg**（录像 / 动检 / 可选 HLS）
- **WiFi 配置与检查**（[WIFI.md](./WIFI.md)）
- **AI 取帧**：RTSP → 448×448 JPEG
- **TPU 人体检测**：MobileDet pedestrian，支持单次与循环检测
- **AI 事件日志**：`events.ndjson`，真实检测事件标记 `source=detect`
- **可选检出录像**：`--record` / `ai_record=1`
- **产品栈 AI 开关**：`ai=1` 后台启动，支持轮询间隔与 cooldown
- **AI VPSS 直取帧**：按需 `Get/ReleaseChnFrame`，不再建立第二个 RTSP 客户端

### 当前限制

- VPSS 帧仍需经 ffmpeg 从 NV12 缩放/编码为 JPEG，但已去掉 RTSP/H.264 解码开销
- `ai_record=1` 仍会额外建立录像 RTSP 客户端，预览敏感场景建议保持关闭
- 默认采用 `ai_interval_sec=20`、`ai_record=0` 降低争用
- 当前是人体/行人检测，不是人脸识别或人脸检测

### 下一步

- `ai=1` + `autostart=1` 家用长稳验收
- 6h 长稳正式收口
- 远程访问（Tailscale，可选）
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
ai=0
ai_interval_sec=20
ai_record=0
ai_frame_source=vpss
```

完整 AI 状态与用法见 [PRODUCT_LITE_AI.md](./PRODUCT_LITE_AI.md)。
