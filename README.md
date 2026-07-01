# EdgeEye Duo S

`EdgeEye Duo S` 是一个面向 **Milk-V Duo S** 的边缘智能摄像头项目。

目标产品：

- 双路 RTSP 直播
- 本地检测 / 识别（后续接入 YOLO）
- 本地录像
- 报警 / 通知
- 浏览器实时查看
- 所有 AI 推理本地完成，不依赖云端

## 当前阶段

当前仓库已经具备：

- 单摄 RTSP（OV5647 on 8554）
- GC2083 单摄预览（554 fallback）
- 运动检测 / 录像脚本骨架
- 自启动 / 健康检查 / 长稳脚本
- 混搭双摄配置与调试记录

当前主阻塞：

- GC2083 尚未稳定走统一的 `8554/cam0` 栈
- 混搭双摄需要 PQ bin 策略
- 浏览器查看 / 本地 AI / 通知仍未实现

## 产品北极星

见：`docs/PRODUCT_FORM3.md`

## 目录

```text
edgeeye-duos/
├── Makefile     # make driver | make app | make
├── config.mk
├── deploy       # 上传 output/ + scripts/ + stream/
├── include/     # debris_uapi.h（用户态）
├── apps/        # motion / stream 脚本 / sync / ai
├── scripts/     # 板上运行与验收脚本
├── configs/     # RTSP JSON / sensor ini（权威配置）
├── board/       # 可选 debris.ko + DTS 片段
├── docs/
├── web/
└── tests/
```

## 构建与部署

在 Docker 内（先 `source /home/work/init_env.sh`）：

```bash
cd /home/work/edgeeye-duos
make              # driver + 用户态 app + 打包 stream 配置
./deploy          # 上传到 192.168.42.1:/root
```

仅驱动：`make driver`。仅用户态与 stream 包：`make app`。

## 快速开始

### 1. 单摄验证（已知可行）

- OV5647：`rtsp://192.168.42.1:8554/cam0`
- GC2083：`rtsp://192.168.42.1:554/h264`（过渡方案）

### 2. 当前主线

先继续 `docs/DEBUG_SESSION/DEBUG_SESSION_ISSUE002.md`，目标是让 GC2083 也走 `8554/cam0`。

## 先读什么

1. `docs/ONBOARDING.md`
2. `docs/PRODUCT_FORM3.md`
3. `docs/PROJECT_STATUS.md`
4. `docs/DEBUG_SESSION/INDEX.md`
5. `docs/CAMERA_VERIFY.md`
