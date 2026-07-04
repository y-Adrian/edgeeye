# board/ — 板级支持

| 子目录 | 用途 |
|--------|------|
| `driver/` | 可选 `debris.ko`（GPIO 动检事件等，`make driver`） |
| `dts/` | `debris-camera-engine.dtsi`，与 SDK 板级 DTS 合并 |

## 构建

```bash
cd edgeeye-duos
source scripts/envsetup.sh
make driver          # → output/debris.ko
```

开发环境见 [docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md)。

## DTS

`dts/debris-camera-engine.dtsi` 定义 `debris-camera` platform 节点。合并进 Milk-V 板级 DTS 后需重新 `pack_boot` 并更新 SD 卡 `boot.sd`（脚本 `scripts/update_boot_sd.sh`）。

板上验证：

```bash
cat /proc/device-tree/debris-camera/compatible
insmod debris.ko register_fallback_pdev=0
cat /proc/debris    # dt_bound=1
```

用户态 ioctl 定义：`include/debris_uapi.h`。
