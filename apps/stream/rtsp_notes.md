# RTSP MVP（待 vendor VENC 集成）

目标地址：

- `rtsp://192.168.42.1:8554/cam0`
- `rtsp://192.168.42.1:8554/cam1`

## 依赖

1. `/dev/video0` 可用（`scripts/check_vendor_media.sh`）
2. SG2000 VENC 硬件编码（`duo-sdk/cvi_mpi/sample/venc/`）
3. `cvi_rtsp`（`duo-sdk/cvi_rtsp/`）

## 下一步实现

- 封装 `sample_venc` 输出 H.264 → `cvi_rtsp` session
- 运动检测触发时提升码率或开始录像文件滚动
- 双路时复制 pipeline 到 cam1

## PC 验证

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
```
