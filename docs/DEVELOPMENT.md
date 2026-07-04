# 开发环境配置

EdgeEye 在 **Mac 宿主机 + Docker 交叉编译 + Milk-V Duo S 板子** 上开发。本文说明从零搭环境到日常编译、部署、调试的完整流程。

---

## 1. 架构总览

```text
┌──────────────── Mac 宿主机 ─────────────────┐
│  Docker (linux/amd64)                        │
│    /home/work  ←挂载→  ~/Documents/learn/riscv │
│      init_env.sh → 工具链 + KDIR             │
│      edgeeye-duos/ → make app → deploy       │
└──────────────────┬──────────────────────────┘
                   │ USB-NCM / 以太网
                   ▼
┌──────────── Milk-V Duo S ────────────────────┐
│  192.168.42.1  root                          │
│  /root/edgeeye_cam  run_edgeeye_stack.sh     │
└──────────────────────────────────────────────┘
```

| 角色 | 路径 / 地址 | 说明 |
|------|-------------|------|
| Mac 工作区 | `~/Documents/learn/riscv` | 本机编辑代码、git |
| Docker 内 | `/home/work` | 与上表 **同一目录**，编译在此进行 |
| SDK | `/home/work/duo-sdk` | 预编译内核、工具链、CVI MPI 头库 |
| 产品仓 | `/home/work/edgeeye-duos` | 本仓库 |
| 驱动学习仓 | `/home/work/debris-ko-learning` | 可选 `debris.ko` |
| 板子 | `root@192.168.42.1` | 部署目录 `/root` |

工作区拆分说明见根目录 [`SPLIT.md`](../../SPLIT.md)。

---

## 2. Mac 宿主机准备

### 2.1 必需

| 工具 | 用途 | 安装 |
|------|------|------|
| **Docker Desktop** | 运行 Milk-V 官方编译镜像 | [docker.com](https://www.docker.com/products/docker-desktop/) |
| **SSH** | 部署、板端调试 | macOS 自带 |
| **ffmpeg**（含 ffplay） | Mac 预览 RTSP、录 clip | `brew install ffmpeg` |

### 2.2 推荐

| 工具 | 用途 |
|------|------|
| USB 转 TTL（CP2102 等） | 串口看 U-Boot / 内核 log（115200 8N1） |
| 以太网 | Duo S 板载网口，比 USB 虚拟网更稳（长稳推流） |

### 2.3 板子连接

**默认：Type-C USB 网络（USB-NCM）**

```bash
ssh root@192.168.42.1
# 出厂常见密码：milkv（若已配免密则直接登录）
```

| 项 | 值 |
|----|-----|
| IP | `192.168.42.1`（板作网关） |
| 用户 | `root` |
| 部署目录 | `/root` |

首次 USB 连接后，Mac 上确认能 `ping 192.168.42.1`。若 SSH 失败，检查系统设置里 USB 网络接口是否已分配地址（一般为 `192.168.42.x`）。

**串口调试（可选）**：Duo S 调试口 TX/RX/GND 接 USB-TTL，参数 `115200 8N1`。启动 log 里 `C.` 开头为 RISC-V 大核，需与拨码开关、固件一致。

---

## 3. Docker 编译环境

### 3.1 启动容器

在 **Mac 终端**执行（路径按本机实际修改）：

```bash
docker run --privileged --platform linux/amd64 -it \
  -v /Users/debris/Documents/learn/riscv:/home/work \
  milkvtech/milkv-duo:latest /bin/bash
```

| 参数 | 原因 |
|------|------|
| `--platform linux/amd64` | 官方镜像为 x86_64；Apple Silicon 必须显式指定 |
| `--privileged` | 部分 SDK/设备节点操作需要 |
| `-v ...:/home/work` | Mac 代码与容器内 **同一份文件**，改代码无需拷进容器 |

日常开发：开一个长期运行的容器即可；新开 shell 时 **每次都要** `source init_env.sh`（见下节）。

### 3.2 初始化环境变量（必做）

进入容器后 **第一个命令**：

```bash
source /home/work/init_env.sh
```

脚本会：

1. `source duo-sdk/build/envsetup_milkv.sh milkv-duos-musl-riscv64-sd`
2. 设置并 **export** `TOP`、`KERNEL_OUTPUT_FOLDER` 等（避免 `make kernel-dts` 污染源码树）
3. 导出交叉编译器：

```text
CROSS_COMPILE=riscv64-unknown-linux-musl-
CC=riscv64-unknown-linux-musl-gcc
```

成功时终端应看到：

```text
env ready: WORK_ROOT=/home/work
env ready: KERNEL_OUTPUT_FOLDER=build/sg2000_milkv_duos_musl_riscv64_sd
env ready: CC=riscv64-unknown-linux-musl-gcc
```

**首次**若提示 `WARN: kernel not configured yet`，说明 SDK 内核 out-of-tree 目录尚无 `.config`，一般 **编 edgeeye_cam 不受影响**；只有改 DTS / 编内核时才需 `build_kernel`。

### 3.3 与 `config.mk` 的关系

`edgeeye-duos/config.mk` 固定使用容器内路径（勿在 Mac 本机直接 `make app`）：

```makefile
ARCH          = riscv
CROSS_COMPILE = riscv64-unknown-linux-musl-
KDIR          = /home/work/duo-sdk/linux_5.10/build/sg2000_milkv_duos_musl_riscv64_sd
```

`make driver` 编 out-of-tree 内核模块时依赖 `KDIR`；`make app` 链 CVI MPI 静态库，同样需在已 `source init_env.sh` 的 shell 里执行。

---

## 4. 编译

在 Docker 内、已 `source init_env.sh`：

```bash
cd /home/work/edgeeye-duos
```

| 命令 | 产出 |
|------|------|
| `make app` | `output/edgeeye_cam`、`output/my_cam_test`、`output/motion_recorder`、sensor ini |
| `make driver` | `output/debris.ko`（可选，动检录像用） |
| `make` | driver + app |
| `make clean` | 清理 build 与 output 二进制 |

产物目录 **`output/`**：

| 文件 | 说明 |
|------|------|
| `edgeeye_cam` | 产品 RTSP 主程序 |
| `my_cam_test` | 分阶段验收（VI/VPSS/VENC/RTSP） |
| `motion_recorder` | 动检录像（需 `debris.ko` + ffmpeg） |
| `stream/*.ini` | 混搭双摄 sensor 配置 |

---

## 5. 部署到板子

### 5.1 从 Docker 内 deploy

容器内通常 **能直接 SSH 到板子**（USB 网络经 Mac 转发）。若不行，可在 **Mac 宿主机**另开终端执行 `./deploy`（同样依赖 `output/` 与 `ssh/scp`）。

```bash
cd /home/work/edgeeye-duos
make app
./deploy
```

`deploy` 会上传：

- `output/` 下所有二进制
- 产品脚本（`run_edgeeye_stack.sh`、`start_my_cam_rtsp.sh` 等）
- `configs/edgeeye_cam.conf` → `/root/edgeeye_cam.conf`
- `web/` → `/root/web/`
- `output/stream/*.ini` → `/root/stream/`

单文件：

```bash
./deploy edgeeye_cam
```

### 5.2 板上首次权限

```bash
ssh root@192.168.42.1
chmod +x /root/*.sh
```

### 5.3 环境变量（可选）

| 变量 | 默认 | 说明 |
|------|------|------|
| `BOARD_IP` | `192.168.42.1` | deploy / 安装脚本 |
| `BOARD_USER` | `root` | SSH 用户 |

---

## 6. Mac 侧日常流程

### 6.1 不进入 Docker：静态测试

在 Mac 上（无需交叉编译）：

```bash
cd ~/Documents/learn/riscv/edgeeye-duos
make test
```

检查脚本语法、sensor ini、deploy 清单等，**不需要板子**。

### 6.2 Mac 预览 RTSP（推荐）

板子已推流时，在 **Mac** 执行：

```bash
cd ~/Documents/learn/riscv/edgeeye-duos

# 一键：SSH 启动板端 + ffplay 弹窗
./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both --start-board

# 或手动
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam1
```

### 6.3 完整 E2E（Docker 编译 + deploy + 板上 suite）

```bash
# Docker 内
source /home/work/init_env.sh
cd /home/work/edgeeye-duos
make test-e2e
```

---

## 7. 板端运行与自启

```bash
ssh root@192.168.42.1

# 编辑配置
vi /root/edgeeye_cam.conf

# 启动完整栈（RTSP + Web + 可选录像）
./run_edgeeye_stack.sh

# 健康检查
./health_check.sh

# 开机自启
./install_autostart.sh
reboot
```

双摄切换若 VPSS/ION 失败：**reboot** 后再 `./run_edgeeye_stack.sh`。

详见 [HOME_USER_GUIDE.md](./HOME_USER_GUIDE.md)。

---

## 8. 板载 ffmpeg（Web 快照 / 本地录像）

官方 rootfs **没有** `ffmpeg` 可执行文件。需在 **Docker 内**交叉编译后安装：

```bash
source /home/work/init_env.sh
cd /home/work/edgeeye-duos
./scripts/build_ffmpeg_cli.sh              # 约 10–20 分钟
./scripts/install_ffmpeg_cli_board.sh      # scp 到 /mnt/data/bin/ffmpeg
```

Mac 上若 Docker 产出在容器 `/tmp`，可先复制到 `output/ffmpeg-riscv64-static` 再：

```bash
FFMPEG_BIN=output/ffmpeg-riscv64-static ./scripts/install_ffmpeg_cli_board.sh
```

编译报错 `rev8` / Zbb：见 [DEPLOYMENT.md](./DEPLOYMENT.md#board-ffmpeg-snapshots--recording)。

---

## 9. IDE 索引（可选）

Docker 内编译完成后，在 **Mac** 刷新 `compile_commands.json` 以便跳转 MPI 头文件：

```bash
cd ~/Documents/learn/riscv/edgeeye-duos
make ide-index
```

依赖工作区根目录的 `scripts/merge_compile_commands.py`（与 `debris-ko-learning` 共用）。

---

## 10. 验收测试

| 层级 | 命令 | 环境 |
|------|------|------|
| L0 静态 | `make test` | Mac 或 Docker |
| L1 板上 phase | `./test_my_cam_test_suite.sh --profile dual-unified -p 5` | SSH 板子 |
| L2 远程 batch | `make test-board` | Mac，须已 deploy |
| L3 E2E | `make test-e2e` | Docker |

用例说明：[tests/camera/TESTCASES.md](../tests/camera/TESTCASES.md)。

---

## 11. 常见问题

| 现象 | 处理 |
|------|------|
| `CROSS_COMPILE: not set` / 找不到 gcc | 未 `source /home/work/init_env.sh` |
| Mac 上 `make app` 失败 | 必须在 **Docker 内**编译，不要在本机裸跑 |
| `deploy` 连不上板子 | 检查 USB 线、ping `192.168.42.1`、Mac 防火墙 |
| 双摄启动 VPSS 失败 | 板端 `reboot`，再 `./run_edgeeye_stack.sh` |
| Docker 很慢 | 确认 `--platform linux/amd64`；Apple Silicon 走模拟 |
| 浏览器无快照 | 板端需安装 ffmpeg；Web 仅为 JPEG 快照非 RTSP 直播 |

---

## 12. 相关文档

| 文档 | 内容 |
|------|------|
| [ONBOARDING.md](./ONBOARDING.md) | 产品能力与五分钟上手 |
| [DEPLOYMENT.md](./DEPLOYMENT.md) | 架构、ffmpeg、双摄技巧 |
| [HARDWARE_NOTES.md](./HARDWARE_NOTES.md) | 摄像头 I2C、GPIO |
| [apps/camera/README.md](../apps/camera/README.md) | `edgeeye_cam` 源码结构 |
