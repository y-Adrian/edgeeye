# EdgeEye Project Status

## 产品目标

目标形态：`docs/PRODUCT_FORM3.md` 中定义的 **形态三**。

## 当前状态（2026-07）

### 已完成

- Duo S 板级构建、部署链路
- **`edgeeye_cam` 产品程序**：单摄/双摄 CLI、`--res` 三档分辨率
- **双摄 RTSP 同时出图**（GC2083 cam0 + OV5647 cam1 @8554）
- Mac 预览脚本 `preview_my_cam_rtsp_mac.sh`
- 库/测试分离：`apps/camera` + `tests/camera/my_cam_test`
- **阶段 B 产品化**：
  - `/root/edgeeye_cam.conf` 配置文件
  - `run_edgeeye_cam.sh` + `install_autostart.sh` 开机自启
  - `health_check.sh` 巡检 edgeeye_cam / RTSP 双路

### 历史能力（仍可用）

- `debris.ko` 及动检 ioctl
- 旧 `rtsp_server` / `run_security.sh` 安防栈（`install_autostart.sh security`）

- **阶段 C 产品化**：
  - `run_edgeeye_stack.sh` — RTSP + 可选动检录像 + Web 快照页
  - `http://192.168.42.1:8080/` 浏览器状态页
  - `stability_6h.sh` 监控 edgeeye_cam 双路
  - 家用说明：`docs/HOME_USER_GUIDE.md`

### 待做

- 6h 长稳收口（进行中）
- HLS/WebRTC 浏览器低延迟直播
- YOLO / 本地通知

## 里程碑对照

| 里程碑 | 状态 |
|--------|------|
| M1 统一 RTSP @8554 | ✅ `edgeeye_cam`（含 GC2083） |
| M2 双路同时直播 | ✅ dual 模式已验证 |
| M3 安防栈整合 | 部分（record=1 + motion_recorder；默认关闭） |
| M4 插电即用 | ✅ 自启 + 配置文件 + Web 页 |
| M5 6h 长稳 | 进行中 |

## 常用命令

```bash
# 编译部署
make app && ./deploy

# 手动启动完整栈
./run_edgeeye_stack.sh

# 浏览器：http://192.168.42.1:8080/
# 家用说明：docs/HOME_USER_GUIDE.md

# 开机自启
./install_autostart.sh && reboot

# 健康检查
./health_check.sh

# Mac 预览
./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both --start-board
```

## 配置文件

`/root/edgeeye_cam.conf`：

```ini
mode=dual
port=8554
res=720p
boot_delay=8
```

模板：`configs/edgeeye_cam.conf`
