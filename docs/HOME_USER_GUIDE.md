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

浏览器快照页（约 3 秒刷新，需板载 ffmpeg + python3）：

```text
http://192.168.42.1:8080/
```

注意：须用 **http://**，不是 https。Duo S 的 busybox 无 httpd，Web 由 **python3 -m http.server** 提供。

## 配置文件

编辑 `/root/edgeeye_cam.conf`：

```ini
mode=dual          # dual | gc2083 | ov5647
port=8554
res=720p           # 1080p | 720p | 480p
record=0           # 1=动检录像（需 debris.ko + ffmpeg）
web=1              # 浏览器状态页
```

改完后：

```bash
./stop_edgeeye_stack.sh
./run_edgeeye_stack.sh
```

## 动检录像

1. 确认 SD 卡挂载：`/mnt/sd/clips` 或 `/mnt/data/clips`
2. 配置 `record=1`，部署 `debris.ko` + `motion_recorder` + ffmpeg
3. 录像文件：`clips/时间戳_cam0.mp4`

手动录一段：

```bash
./record_clip.sh 30 cam0
```

## 开机自启

```bash
./install_autostart.sh
reboot
```

重启后无需 SSH，Mac 直接 ffplay 即可。

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

## 日志位置

| 文件 | 内容 |
|------|------|
| `/tmp/edgeeye_stack.log` | 产品栈启动 |
| `/tmp/edgeeye_cam_rtsp.log` | edgeeye_cam 推流 |
| `/tmp/stability_6h.log` | 长稳测试 |
