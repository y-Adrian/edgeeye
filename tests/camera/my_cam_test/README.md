# my_cam_test — 板上渐进验收程序

本目录是 **测试/验收代码**，链接 `apps/camera/` 管线库编译为 `output/my_cam_test`。

| 文件 | 职责 |
|------|------|
| `my_cam_test.c` | CLI、phase 调度、bringup 选项 |
| `cam_test_phases.c/h` | phase 2～8 编排与验收阈值检查 |
| `cam_test_config.h` | 默认路径、phase 常量、VB 配置辅助 |
| `Makefile` | 交叉编译入口 |

库源码在 [`apps/camera/`](../../../apps/camera/)。部署后板上路径仍为 `/root/my_cam_test`。

```bash
# Docker 内
cd edgeeye-duos && source scripts/envsetup.sh && make app && ./deploy
ssh root@192.168.42.1 '/root/my_cam_test -p 2'
```
