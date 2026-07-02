# EdgeEye Project Status

## 产品目标

目标形态：`docs/PRODUCT_FORM3.md` 中定义的 **形态三**。

## 当前状态（2026-07）

### 已完成基础能力

- Duo S 板级构建、部署链路
- `debris.ko` 及基础板级支持可用
- **双摄分别可预览**（归档见 `docs/CAMERA_BRINGUP_ARCHIVE.md`）
  - OV5647：`8554/cam0`（rtsp_server）
  - GC2083：`554/h264`（camera-test）
- motion / recorder / health / autostart / stability 脚本已具备骨架
- 混搭双摄 ini/json 已存在

### 当前阻塞

- ISSUE-002 部分收口：GC2083 **不能**走 `rtsp_server` @8554
- M2 同时双流：混合双栈不可行；须 `cam_dual` 或修 GC2083
- 混搭双摄需要 PQ bin 方案
- 浏览器查看、YOLO、本地通知尚未实现

## 与形态三里程碑对照

| 里程碑 | 状态 |
|--------|------|
| M1 统一 RTSP（GC2083 @ 8554） | ❌ 阻塞（554 workaround 可用） |
| M2 双路同时直播 | 未开始（ISSUE-003） |
| M3 安防栈整合 | 未开始 |
| M4 插电即用 | 未开始 |
| M5 6h 长稳 | 未开始 |

## 当前建议优先级

1. 新建 ISSUE-003：`rtsp_dual_mixed` + 双摄同时直播
2. 并行向 Milk-V 问 GC2083 @ rtsp_server 方案
3. 日常预览用 `CAMERA_BRINGUP_ARCHIVE.md` 配方
