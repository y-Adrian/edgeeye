# 开发环境配置

EdgeEye 在 **Mac 宿主机 + Docker 交叉编译 + Milk-V Duo S 板子** 上开发。本文说明从零搭环境到日常编译、部署、调试的完整流程。所有步骤均在本仓库内完成，不依赖其他 git 仓库里的文档或脚本。

---

## 0. 版本与基线

以下为本项目 **开发与验证时使用的环境基线**。SDK 可随 Milk-V 官方更新，但交叉编译器、MPI 与板端 rootfs **须同一 SDK 代系**，否则链接或运行可能异常。

### 0.1 硬件与板端镜像

| 项 | 值 |
|----|-----|
| 开发板 | **Milk-V Duo S** |
| SoC | **SG2000**（CV181x，C906 RISC-V 大核 + Cortex-A53 小核） |
| RISC-V CPU | **T-Head C906**（`-mcpu=c906fdv`，`-march=rv64imafdcv0p7xthead`） |
| 启动介质 | SD 卡 |
| 板端连接 | USB-NCM `192.168.42.1`，用户 `root` |
| 出厂 root 密码 | `milkv`（若未改） |
| EdgeEye 部署目录 | `/root` |

板端应使用与 **Duo S musl RISC-V SD** 对应的官方 Buildroot 镜像（与下节 SDK 同代）。若自行重编内核/DTS，须用同一 `duo-sdk` 的 `pack_boot` 更新 SD 上 `boot.sd`。

### 0.2 Milk-V SDK（duo-sdk）

| 项 | 值 |
|----|-----|
| 名称 | **Milk-V Duo Buildroot SDK V2** |
| 上游仓库 | [github.com/milkv-duo/duo-buildroot-sdk-v2](https://github.com/milkv-duo/duo-buildroot-sdk-v2) |
| 本地目录名 | `duo-sdk`（与 `edgeeye-duos` **同级**） |
| envsetup 板型 | `milkv-duos-musl-riscv64-sd` |
| SDK 内部板型链接 | `sg2000_milkv_duos_musl_riscv64_sd` |
| 内核版本 | **Linux 5.10** |
| Bootloader | **U-Boot 2021.10** |
| Rootfs | **Buildroot + musl**（RISC-V 大核） |
| 内核 out-of-tree 目录 | `linux_5.10/build/sg2000_milkv_duos_musl_riscv64_sd` |
| 已验证 commit（参考） | `e7fefaa9f`（2026-06-02） |

`scripts/envsetup.sh` 固定加载上述板型；`config.mk` 中 `KDIR` 指向上表内核输出目录。

**获取 SDK：**

```bash
cd ~/dev    # 与 edgeeye-duos 同级
git clone https://github.com/milkv-duo/duo-buildroot-sdk-v2.git duo-sdk
cd duo-sdk
# 可选：与项目验证时对齐
git checkout e7fefaa9f
```

完整编译 SDK 耗时长，步骤见 [Milk-V Buildroot SDK 文档](https://milkv.io/docs/duo/getting-started/buildroot-sdk)。**仅编 EdgeEye 用户态** 时，通常只需 SDK 已含 `cvi_mpi/`、`build/.config` 与 `host-tools/`（官方 Docker 镜像或预编译包一般已满足）。

**自检 SDK 是否就绪：**

```bash
test -f duo-sdk/build/envsetup_milkv.sh && echo OK envsetup
test -f duo-sdk/cvi_mpi/mpi_param.mk && echo OK MPI
test -d duo-sdk/host-tools/gcc/riscv64-linux-musl-x86_64 && echo OK toolchain
```

`source scripts/envsetup.sh` 成功后会打印 `DUO_SDK_REV=`（若 SDK 为 git clone）。

### 0.3 交叉工具链

| 项 | 值 |
|----|-----|
| 前缀 | `riscv64-unknown-linux-musl-` |
| GCC | **10.2.0**（SDK `host-tools/gcc/riscv64-linux-musl-x86_64`） |
| C 库 | **musl** |
| 内核头 | **5.10**（与板端内核一致） |
| 典型编译标志 | `-mcpu=c906fdv -mabi=lp64d -mcmodel=medany` |

Docker 内验证：

```bash
source scripts/envsetup.sh
${CROSS_COMPILE}gcc --version
# 期望含：gcc (GCC) 10.2.0 ... riscv64-unknown-linux-musl
```

**注意：** 该工具链的 binutils **不支持 RISC-V Zbb**（`rev8` / `.option arch,+zbb`）。交叉编译 **FFmpeg 6.x** 时必须加 `--disable-asm --disable-rvv`（见 `scripts/build_ffmpeg_cli.sh`）。

### 0.4 Docker 编译镜像

| 项 | 值 |
|----|-----|
| 镜像 | `milkvtech/milkv-duo:latest` |
| 架构 | **linux/amd64**（Apple Silicon Mac 必须 `--platform linux/amd64`） |
| 用途 | 提供 x86_64 下的 SDK 工具链运行环境；代码通过 `-v` 挂载 |

E2E 测试默认镜像同上，可通过 `DOCKER_IMAGE` 覆盖。

### 0.5 摄像头与 sensor 配置（产品默认）

| 接口 | Sensor | I2C | 地址 | RTSP 路径 |
|------|--------|-----|------|-----------|
| **J1** | GC2083（Milk-V 官方 2MP） | i2c-3 | 0x37 | `:8554/cam0` |
| **J2** | OV5647（树莓派模块） | i2c-2 | 0x36 | `:8554/cam1` |

双摄混搭 ini：`configs/sensor/sensor_cfg_GC2083_OV5647_dual.ini`。硬件细节见 [HARDWARE_NOTES.md](./HARDWARE_NOTES.md)。

SDK defconfig 已启用 `CONFIG_SENSOR_GCORE_GC2083`、`CONFIG_SENSOR_OV_OV5647` 等；板端 `/mnt/data/sensor_cfg.ini` 由 deploy/启动脚本维护。

### 0.6 板载 ffmpeg（可选）

| 项 | 值 |
|----|-----|
| 交叉编译版本 | **FFmpeg 6.1.1**（`scripts/build_ffmpeg_cli.sh`，静态链接） |
| 用途 | Web JPEG 快照、本地 RTSP 录像 |
| 官方 rootfs | **无** `ffmpeg` CLI；可选 SDK 包内 **ffprobe**（`install_ffprobe_board.sh`） |

### 0.7 EdgeEye 构建产物（本仓库）

| 命令 | 主要产出 |
|------|----------|
| `make app` | `output/edgeeye_cam`、`output/my_cam_test`、`output/motion_recorder` |
| `make driver` | `output/debris.ko`（可选） |
| `./deploy` | 上传到板子 `/root/` |

媒体栈：**CVI MPI**（VI / ISP / VPSS / VENC）+ **Sophon RTSP**（`duo-sdk/sophapp/prebuilt/rtsp`）。

---

## 1. 目录布局

编译 **必须** 有 Milk-V `duo-sdk`（工具链、CVI MPI、内核 out-of-tree 输出）。推荐与本仓库 **同级** 放置：

```text
your-workspace/
  edgeeye-duos/     ← 本仓库（clone 远端即可）
  duo-sdk/          ← Milk-V Buildroot SDK（单独获取，见 §0.2）
```

| 角色 | 典型路径 | 说明 |
|------|----------|------|
| Mac 本机 | `~/dev/edgeeye-duos` | 编辑代码、git |
| Mac 本机 | `~/dev/duo-sdk` | SDK（与上表同级） |
| Docker 内 | `/work/edgeeye-duos` | 挂载后的本仓库 |
| Docker 内 | `/work/duo-sdk` | 挂载后的 SDK |
| 板子 | `root@192.168.42.1` | 部署目录 `/root` |

若 SDK 不在默认位置，编译前设置：

```bash
export DUO_SDK_ROOT=/path/to/duo-sdk
```

---

## 2. 准备 duo-sdk

`duo-sdk` **不在** EdgeEye 远端仓库中。版本、板型、工具链等基线见上文 **[§0.2–0.3](#02-milk-v-sdkduo-sdk)**。

简要步骤：

1. 与 `edgeeye-duos` 同级 clone [duo-buildroot-sdk-v2](https://github.com/milkv-duo/duo-buildroot-sdk-v2) 为 `duo-sdk`。
2. （推荐）`git checkout e7fefaa9f` 与项目验证 commit 对齐。
3. 确认存在 `cvi_mpi/`、`host-tools/`、`build/envsetup_milkv.sh`。
4. 仅改 DTS/内核时再在 SDK 内 `build_kernel`、`pack_boot`；**只编 EdgeEye** 通常不需要。

`scripts/envsetup.sh` 会执行：

```bash
source duo-sdk/build/envsetup_milkv.sh milkv-duos-musl-riscv64-sd
```

并导出 `CROSS_COMPILE`、`KERNEL_OUTPUT_FOLDER` 等。

更完整的 SDK 获取与首次编译说明：[Milk-V Buildroot SDK 文档](https://milkv.io/docs/duo/getting-started/buildroot-sdk)。

---

## 3. Mac 宿主机准备

### 3.1 必需

| 工具 | 用途 | 安装 |
|------|------|------|
| **Docker Desktop** | 运行 Milk-V 官方编译镜像 | [docker.com](https://www.docker.com/products/docker-desktop/) |
| **SSH** | 部署、板端调试 | macOS 自带 |
| **ffmpeg**（含 ffplay） | Mac 预览 RTSP | `brew install ffmpeg` |

### 3.2 推荐

| 工具 | 用途 |
|------|------|
| USB 转 TTL（CP2102 等） | 串口看 U-Boot / 内核 log（115200 8N1） |
| 以太网 | Duo S 板载网口，长稳推流更稳 |

### 3.3 板子连接

**默认：Type-C USB 网络（USB-NCM）**

```bash
ssh root@192.168.42.1
```

| 项 | 值 |
|----|-----|
| IP | `192.168.42.1` |
| 用户 | `root` |
| 部署目录 | `/root` |

---

## 4. Docker 编译环境

### 4.1 启动容器

在 Mac 终端执行（把 `~/dev` 换成你的 **父目录**，其中包含 `edgeeye-duos` 与 `duo-sdk`）：

```bash
docker run --privileged --platform linux/amd64 -it \
  -v ~/dev:/work \
  milkvtech/milkv-duo:latest /bin/bash
```

| 参数 | 原因 |
|------|------|
| `--platform linux/amd64` | 官方镜像为 x86_64；Apple Silicon 必须显式指定 |
| `--privileged` | 部分 SDK 操作需要 |
| `-v ~/dev:/work` | Mac 与容器共享同一份代码 |

**仅挂载本仓库、SDK 另路径时** 可分别挂载并设置 `DUO_SDK_ROOT`：

```bash
docker run --privileged --platform linux/amd64 -it \
  -v ~/dev/edgeeye-duos:/work/edgeeye-duos \
  -v ~/path/to/duo-sdk:/work/duo-sdk \
  milkvtech/milkv-duo:latest /bin/bash
```

### 4.2 初始化环境变量（必做）

进入容器后，**每次新开 shell** 执行：

```bash
cd /work/edgeeye-duos
source scripts/envsetup.sh
```

脚本位于本仓库 `scripts/envsetup.sh`，会：

1. 解析 `DUO_SDK_ROOT` 或 `../duo-sdk`
2. `source duo-sdk/build/envsetup_milkv.sh milkv-duos-musl-riscv64-sd`
3. 导出 `CROSS_COMPILE`、`CC`、`KERNEL_OUTPUT_FOLDER` 等

成功时终端应看到：

```text
env ready: EDGEEYE_ROOT=/work/edgeeye-duos
env ready: DUO_SDK_ROOT=/work/duo-sdk
env ready: MILKV_BOARD=milkv-duos-musl-riscv64-sd
env ready: KERNEL_OUTPUT_FOLDER=build/sg2000_milkv_duos_musl_riscv64_sd
env ready: CC=riscv64-unknown-linux-musl-gcc
env ready: DUO_SDK_REV=e7fefaa9f    # git clone 时才有
```

**首次**若提示 `WARN: kernel not configured yet`，一般 **编 edgeeye_cam 不受影响**；改 DTS / 编内核时再在 SDK 内 `build_kernel`。

### 4.3 与 `config.mk` 的关系

`config.mk` 通过相对路径定位 SDK：

```makefile
DUO_SDK ?= $(abspath $(ROOT_DIR)/../duo-sdk)
KDIR    := $(DUO_SDK)/linux_5.10/build/sg2000_milkv_duos_musl_riscv64_sd
```

`make app` 与 `make driver` 均须在已 `source scripts/envsetup.sh` 的 shell 中执行；**不要在 Mac 本机裸跑** `make app`（缺少交叉工具链与 MPI）。

---

## 5. 编译

```bash
cd /work/edgeeye-duos   # 或你的挂载路径
source scripts/envsetup.sh
```

| 命令 | 产出 |
|------|------|
| `make app` | `output/edgeeye_cam`、`my_cam_test`、`motion_recorder`、sensor ini |
| `make driver` | `output/debris.ko`（可选，动检录像用） |
| `make` | driver + app |
| `make clean` | 清理 build 与 output |

---

## 6. 部署到板子

```bash
make app
./deploy
```

`deploy` 上传二进制、脚本、`configs/edgeeye_cam.conf`、`web/`、`output/stream/*.ini` 等到 `/root/`。

单文件：`./deploy edgeeye_cam`

环境变量：`BOARD_IP`（默认 `192.168.42.1`）、`BOARD_USER`（默认 `root`）。

---

## 7. Mac 侧日常流程

### 7.1 静态测试（无需板子）

```bash
cd ~/dev/edgeeye-duos
make test
```

### 7.2 Mac 预览 RTSP

```bash
./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both --start-board

ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
```

### 7.3 E2E（Docker 编译 + deploy + 板上 suite）

```bash
make test-e2e
```

`run_e2e.sh` 默认把 **edgeeye-duos 的父目录** 挂到容器 `/work`，并在容器内 `source scripts/envsetup.sh`。

---

## 8. 板端运行

```bash
ssh root@192.168.42.1
vi /root/edgeeye_cam.conf
./run_edgeeye_stack.sh
./health_check.sh
./install_autostart.sh   # 可选开机自启
```

双摄 VPSS/ION 失败时：**reboot** 后再启动。详见 [HOME_USER_GUIDE.md](./HOME_USER_GUIDE.md)。

---

## 9. 板载 ffmpeg

rootfs 默认无 `ffmpeg`。Docker 内：

```bash
source scripts/envsetup.sh
./scripts/build_ffmpeg_cli.sh
./scripts/install_ffmpeg_cli_board.sh
```

详见 [DEPLOYMENT.md](./DEPLOYMENT.md#board-ffmpeg-snapshots--recording)。

---

## 10. IDE 索引（可选）

Docker 内 `make app` 后，在 Mac：

```bash
make ide-index
```

生成仓库根目录 `compile_commands.json`（`scripts/gen_compile_commands.py`）。

---

## 11. 验收测试

| 层级 | 命令 | 环境 |
|------|------|------|
| L0 静态 | `make test` | Mac 或 Docker |
| L1 板上 | `./test_my_cam_test_suite.sh --profile dual-unified -p 5` | SSH 板子 |
| L2 远程 | `make test-board` | Mac，须已 deploy |
| L3 E2E | `make test-e2e` | Docker |

用例：[tests/camera/TESTCASES.md](../tests/camera/TESTCASES.md)。

---

## 12. 常见问题

| 现象 | 处理 |
|------|------|
| `duo-sdk not found` | 与 `edgeeye-duos` 同级放置 SDK，或 `export DUO_SDK_ROOT=...` |
| `CROSS_COMPILE not set` | 未 `source scripts/envsetup.sh` |
| `missing cvi_mpi/mpi_param.mk` | SDK 不完整；重新 clone 或按 §0.2 自检 |
| 链 MPI 报错 / 板上 segfault | SDK 与板端镜像代系不一致；对齐 `DUO_SDK_REV` 或重刷官方 Duo S musl 镜像 |
| Mac 上 `make app` 失败 | 必须在 Docker 内编译 |
| `deploy` 连不上板子 | ping `192.168.42.1`、检查 USB 网络 |
| 双摄 VPSS 失败 | 板端 `reboot` |
| ffmpeg 编不过 `rev8` | 使用本仓 `build_ffmpeg_cli.sh`（已 disable asm/rvv） |
| 浏览器无快照 | 板端需安装 ffmpeg |

---

## 13. 相关文档

| 文档 | 内容 |
|------|------|
| [ONBOARDING.md](./ONBOARDING.md) | 产品能力与五分钟上手 |
| [DEPLOYMENT.md](./DEPLOYMENT.md) | 架构、ffmpeg、双摄 |
| [HARDWARE_NOTES.md](./HARDWARE_NOTES.md) | 摄像头 I2C、GPIO |
| [board/README.md](../board/README.md) | `debris.ko`、DTS 片段 |
| [apps/camera/README.md](../apps/camera/README.md) | `edgeeye_cam` 源码 |
