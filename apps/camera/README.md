# camera — 自研推流学习程序

按阶段从 VI 到 RTSP 逐步实现。当前：**阶段 5**（RTSP 实时预览）。

## 阶段 2：`my_cam_test -p 2`

仅初始化 VI + ISP，不推流。等价于精简版 `sample_sensor_test`。

### 编译（Docker）

```bash
source /home/work/init_env.sh
cd /home/work/edgeeye-duos
make app
# 产物：output/my_cam_test
```

需已 `build_middleware`（`cvi_mpi` 库与头文件存在）。

### IDE 代码跳转（Cursor / clangd）

工作区使用 **clangd**（已禁用 C/C++ 扩展）。`my_cam_test.c` 里 `Cmd+点击` 跳到 `SAMPLE_COMM_*`、SDK 头文件需先生成索引：

```bash
# Docker 内编译后，在 macOS 宿主机执行
cd edgeeye-duos && make ide-index
# 或只打开 edgeeye-duos 目录时同样执行 make ide-index
```

会生成 `edgeeye-duos/compile_commands.json` 并合并到工作区根 `compile_commands.json`。修改后执行 **Developer: Restart Language Server** 或重载窗口。

若未安装 clangd：`brew install llvm`，将 `$(brew --prefix llvm)/bin` 加入 PATH。

### 板上验证

```bash
# 停掉占摄像头的进程（勿用裸 grep my_cam_test，会误杀 test_my_cam_test*.sh）
for p in $(ps | grep -v grep | grep -v test_my_cam_test | grep -E '/my_cam_test[[:space:]]|/sample_vi|rtsp_server' | awk '{print $1}'); do kill $p; done

# GC2083 @ J1
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
/root/my_cam_test -p 2
# 或
/root/my_cam_test -p 2 -s 15
```

或使用 `scripts/test_my_cam_test.sh gc2083` / `ov5647`。

**切换另一颗头（J2 OV5647）：**

```bash
# 通用：阶段 + 传感器（scripts/test_my_cam_test*.sh 与 my_cam_test_common.sh 须同目录部署）
scripts/test_my_cam_test_phase.sh 5 ov5647

# 或手动链 ini 后运行
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
/root/my_cam_test -p 5 -s 30
```

Mac 预览地址不变：`rtsp://192.168.42.1:8554/cam0`（换的是物理镜头，不是 URL）。

## 阶段 3：VPSS 抓一帧 YUV

在阶段 2 基础上：VI 绑定 VPSS，等待 AE 收敛后 `GetChnFrame`，保存 NV12 到文件。

```bash
# 停旧媒体进程 + 链 ini（同阶段 2）
/root/my_cam_test -p 3 -o /tmp/frame.yuv
```

验收脚本：

```bash
scripts/test_my_cam_test_phase3.sh gc2083
```

**Mac 上看这一帧（无 RTSP，仅 raw YUV）：**

```bash
scp root@192.168.42.1:/tmp/frame.yuv .
# ffplay 8.x 用 -pixel_format，不是 -pix_fmt
ffplay -f rawvideo -pixel_format nv12 -video_size 1920x1080 frame.yuv

# 或转成 PNG 更直观（单帧）
ffmpeg -f rawvideo -pixel_format nv12 -video_size 1920x1080 -i frame.yuv -frames:v 1 preview.png
open preview.png
```

日志应含 `saved 1920x1080 NV12 -> ...` 与 `PASSED (phase 3)`。

## 阶段 4：VENC 写 H.264 文件

在阶段 3 管线上绑定 VENC，采集约 1 秒码流写入裸 H.264 文件（仍无 RTSP）。

```bash
/root/my_cam_test -p 4 -o /tmp/frame.h264
```

验收脚本：

```bash
scripts/test_my_cam_test_phase4.sh gc2083
```

**Mac 上播放：**

```bash
scp root@192.168.42.1:/tmp/frame.h264 .
ffplay frame.h264
```

日志应含 `saved H264 -> ...` 与 `PASSED (phase 4)`；文件通常 ≥ 几十 KB。

## 阶段 5：RTSP 实时预览

在阶段 4 管线上接入 `cvi_rtsp`：VENC 码流经 `CVI_RTSP_WriteFrame` 推到 RTSP 服务。

```bash
# 停旧媒体进程 + 链 ini（同阶段 2）
/root/my_cam_test -p 5 -s 30 -P 8554 -u cam0
```

验收脚本：

```bash
scripts/test_my_cam_test_phase5.sh gc2083
```

**Mac 上实时预览：**

```bash
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
```

日志应含 `RTSP streamed N frames` 与 `PASSED (phase 5)`。推流期间可用 `netstat -ln | grep 8554` 确认端口监听。

默认参数：端口 `8554`、路径 `cam0`、推流时长 `30` 秒（`-s` 可调，Ctrl+C 可提前结束）。

### 调试（程序异常退出时）

板上自带 **gdb / gdbserver / strace**：

```bash
# 1) 对照官方程序（先确认硬件/ini 正常）
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
echo 255 | /mnt/system/usr/bin/sample_sensor_test

# 2) 详细 MPI 日志
/root/my_cam_test -v -s 5 2>&1 | tee /tmp/my_cam_test.log

# 3) 跟踪系统调用（看 ioctl 失败）
strace -f -o /tmp/my.strace /root/my_cam_test -s 3 2>/tmp/my.out
grep '= -1' /tmp/my.strace | grep -v ENOENT

# 4) GDB 单步（段错误时）
ulimit -c unlimited
gdb /root/my_cam_test
# (gdb) run -s 3
# (gdb) bt

# 5) 内核/驱动侧
dmesg | tail -30
cat /proc/cvitek/vi 2>/dev/null | head -20
ps | grep cvitask
```

**常见原因：**

| 现象 | 处理 |
|------|------|
| `VI_Init failed 0xffffffff`，官方 `sample_sensor_test` 正常 | 重编：`BUILD_PATH` 须指向 `duo-sdk/build`（含 `CONFIG_SENSOR_GCORE_GC2083`） |
| 有 `cvitask_*` 残留线程 | 停 `sample_vi`/`rtsp_server`，或 **reboot** 后再测 |
| Segmentation fault | `gdb` + `bt`；确保用 `-g` 编译（默认已带 debug_info） |
| MMF Version 与固件不一致 | Docker 内 `source init_env.sh` 后重编，勿混用旧 `.o` |

Mac 上远程 GDB（可选）：

```bash
# 板上
gdbserver :1234 /root/my_cam_test -s 10
# Mac/Docker（需 riscv64 gdb）
riscv64-unknown-linux-musl-gdb output/my_cam_test -ex 'target remote 192.168.42.1:1234'
```
