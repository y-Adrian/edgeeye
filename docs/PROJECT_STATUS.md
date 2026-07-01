# EdgeEye Project Status

## 产品目标

目标形态：`docs/PRODUCT_FORM3.md` 中定义的 **形态三**。

## 当前状态（2026-06）

### 已完成基础能力

- Duo S 板级构建、部署链路
- `debris.ko` 及基础板级支持可用
- OV5647 单摄 RTSP 已验证
- GC2083 单摄预览已验证（554 fallback）
- motion / recorder / health / autostart / stability 脚本已具备骨架
- 混搭双摄 ini/json 已存在

### 当前阻塞

- ISSUE-002：GC2083 尚未稳定接入统一 `8554/cam0`
- 混搭双摄需要 PQ bin 方案
- `run_security.sh` 双摄分支仍需切到 mixed 主线
- 浏览器查看、YOLO、本地通知尚未实现

## 与形态三里程碑对照

| 里程碑 | 状态 |
|--------|------|
| M1 统一 RTSP（GC2083 @ 8554） | 进行中 |
| M2 双路同时直播 | 未开始 |
| M3 安防栈整合 | 未开始 |
| M4 插电即用 | 未开始 |
| M5 6h 长稳 | 未开始 |

## 当前建议优先级

1. 完成 ISSUE-002 Step 1 及后续变体
2. 新建 ISSUE-003：混搭双摄同时直播
3. 修改 `run_security.sh` 双摄分支走 mixed 脚本
4. 明确浏览器方案（HLS / WebRTC）
5. 规划本地 YOLO 接入点
