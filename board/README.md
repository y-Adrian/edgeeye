# board/ — 产品运行所需的板级支持

本目录**不是**驱动学习主线；完整 `debris.ko` 学习与测试见独立仓库 `debris-ko-learning/`。

| 子目录 | 用途 |
|--------|------|
| `driver/` | 产品侧可选的 `debris.ko` 副本（事件层 / GPIO 运动等） |
| `dts/` | `debris-camera-engine.dtsi`，与 SDK 板级 DTS 合并 |

构建与烧录：

```bash
# Docker 内
source /home/work/init_env.sh
cd /home/work/edgeeye-duos
make driver          # 仅 debris.ko → output/
```

DTS 工作流与 `debris-ko-learning` 相同，见 `docs/DEPLOYMENT.md` 与 `debris-ko-learning/docs/DTS_WORKFLOW.md`。

用户态 ioctl 定义在仓库根目录 `include/debris_uapi.h`。
