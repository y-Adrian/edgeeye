# Web — EdgeEye 浏览器双摄页

部署到板子 `/root/web/`，由 `serve_edgeeye_web.sh` 启动。

## 访问

```text
http://192.168.42.1:8080/
```

| `web_live` | 效果 |
|------------|------|
| `hls`（默认） | 双路 **HLS** 直播（hls.js / Safari 原生），延迟约数秒 |
| `snapshot` | JPEG 快照约 3 秒刷新（旧行为） |

完整低延迟仍可用：

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam1
```

## 配置

`/root/edgeeye_cam.conf`：

```ini
web=1
web_port=8080
web_live=hls        # hls | snapshot
record=0            # 开 HLS 时建议关动检，少抢 RTSP
```

## 依赖

1. 板载 ffmpeg 需含 **HLS muxer**（本仓 `build_ffmpeg_cli.sh` 已启用）
2. 重新编译安装：

```bash
./scripts/build_ffmpeg_cli.sh
./scripts/install_ffmpeg_cli_board.sh
```

3. 板子验证：`/mnt/data/bin/ffmpeg -muxers | grep hls`

## 架构

```text
edgeeye_cam RTSP :8554/cam0+cam1
        │
        ├─ ffmpeg -c copy → web/hls/cam0.m3u8
        └─ ffmpeg -c copy → web/hls/cam1.m3u8
                │
        python edgeeye_http_server.py :8080
                │
        浏览器 hls.js 双路 <video>
```

`-c copy` 不解码，比 JPEG 快照更省算力，但仍各占一路 RTSP 客户端。
