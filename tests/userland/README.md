# Userland Tests

## Camera（my_cam_test）

| 层级 | 命令 | 环境 |
|------|------|------|
| 本地静态 | `make test` | macOS / CI，无需板子 |
| 板上验收 | `scripts/test_my_cam_test_phase.sh <2-8>` | Duo S |
| 板上批量 | `tests/camera/run_board_tests.sh` | SSH |

用例清单见 [`camera/TESTCASES.md`](camera/TESTCASES.md)。

## 后续（产品里程碑）

- 单摄 RTSP soak test
- 双摄 RTSP soak test
- motion_recorder 触发测试
- autostart / reboot 验收测试
