# Migration Notes

本仓库由原混合项目拆分而来（原 `Camera/` 已删除），目标是只保留产品侧内容。

## 已迁入

- `apps/`：motion / stream / sync
- `scripts/`：运行、恢复、验收、自启、长稳
- `configs/`：RTSP JSON 与双摄 sensor 配置
- `board/`：产品运行仍需要的最小板级支持
- `docs/`：产品目标、硬件、调试会话、验收说明

## 结构清理（已完成）

- 根目录 `Makefile` / `config.mk` / `deploy` 统一构建与上传
- RTSP JSON 与 sensor ini 权威目录：`configs/`（`apps/stream/` 仅保留启停脚本）
- 用户态 ioctl：`include/debris_uapi.h`
- `.gitignore` 忽略 `build/`、`output/*`、kbuild 生成物
- 已删除误提交的 `debris.mod.c` 与重复的 `board/deploy`

## 尚未产品化的部分

- `apps/ai/` 仅占位，YOLO 尚未接入
- `web/` 仅占位，浏览器实时查看尚未实现
- 双路混搭 RTSP 仍受 ISSUE-002 / ISSUE-003 阻塞

## 建议的下一步

1. 完成 `docs/DEBUG_SESSION/DEBUG_SESSION_ISSUE002.md`
2. 新建 ISSUE-003，推进混搭双摄 `cam0` + `cam1`
3. 修改 `scripts/run_security.sh` 的双摄分支走 mixed 脚本
