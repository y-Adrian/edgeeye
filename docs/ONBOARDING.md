# EdgeEye 上手指南

## 1. 这是什么

这是一个要落地成 **家用边缘智能摄像头** 的产品仓库。

最终目标：

```text
有人进入画面
    ↓
Camera采集
    ↓
ISP图像增强
    ↓
YOLO检测
    ↓
检测到人
    ↓
开始录像
    ↓
RTSP直播
    ↓
手机收到通知
    ↓
浏览器查看实时画面
```

目前并不是全部都已实现。

## 2. 当前已经有的能力

- Duo S 板级部署与脚本
- 单摄 RTSP 路径
- 运动检测 / 录像脚本骨架
- 自动启动、健康检查、长稳脚本
- 混搭双摄配置文件
- 详细的 DEBUG_SESSION 调试记录

## 3. 当前最重要的现实情况

| 摄像头 | 当前可用路径 | 说明 |
|--------|-------------|------|
| OV5647 (J2) | `rtsp://192.168.42.1:8554/cam0` | 单摄已验证 |
| GC2083 (J1) | `rtsp://192.168.42.1:554/h264` | 过渡方案，不算最终产品完成 |

**形态三必须做到：** GC2083 也走 `8554/cam0`，并且与 OV5647 组成双路直播。

## 4. 仓库结构怎么看

- `apps/motion/`：运动检测与录像触发相关代码
- `apps/stream/`：RTSP 相关配置与脚本
- `apps/sync/`：双路同步探针占位
- `apps/ai/`：本地 YOLO / 识别能力占位
- `scripts/`：板上运行、恢复、验收、自启动脚本
- `configs/`：json / ini / PQ 相关配置
- `board/`：当前产品运行仍需要的板级支持
- `web/`：未来浏览器查看入口占位
- `docs/`：产品目标、硬件、验证记录、DEBUG_SESSION

## 5. 你先读什么

### 产品视角

1. `docs/PRODUCT_FORM3.md`
2. `docs/PROJECT_STATUS.md`
3. `docs/DEBUG_SESSION/INDEX.md`

### 摄像头调试视角

1. `docs/SINGLE_CAM_BRINGUP.md`
2. `docs/CAMERA_VERIFY.md`
3. `docs/DEBUG_SESSION/DEBUG_SESSION_ISSUE002.md`

### 部署视角

1. `docs/DEPLOYMENT.md`
2. `scripts/run_security.sh`
3. `scripts/verify_board.sh`

## 6. 第一天建议动手顺序

1. 板上验证单摄各自可出图
2. 读 `PRODUCT_FORM3.md` 里的 M1–M5
3. 从 ISSUE-002 继续推进 GC2083 @ 8554
4. M1 过后，再开混搭双摄 ISSUE-003

## 7. 重要边界

- 本仓库的“视频能不能出图”，主要依赖厂商媒体栈
- `board/driver/debris.ko` 在这里是**板级辅助/事件层**，不是完整视频链主责任人
- 浏览器查看、YOLO、本地通知目前还未实现，只能作为接下来的产品主线
