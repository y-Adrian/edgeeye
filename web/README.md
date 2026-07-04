# Web — EdgeEye 浏览器状态页

部署到板子 `/root/web/`，由 `serve_edgeeye_web.sh` 启动 busybox httpd。

## 访问

```text
http://192.168.42.1:8080/
```

- JPEG 快照约 3 秒刷新（需板载 ffmpeg + `edgeeye_snapshots.sh`）
- 完整 RTSP 直播仍用 VLC / ffplay

## 配置

`/root/edgeeye_cam.conf`：

```ini
web=0              # 0=关  1=开浏览器快照页
web_port=8080
snapshot_sec=3
```

## 说明

浏览器无法直接播放 RTSP；本页提供低延迟快照预览 + RTSP 链接。
后续可接 HLS/WebRTC 桥接。
