# camera — EdgeEye 摄像头媒体管线库

`apps/camera/` 保留 **可复用的 MPI 管线代码**（VI/ISP/VPSS/VENC/RTSP）。  
产品二进制 **`edgeeye_cam`** 与验收程序 **`my_cam_test`** 分别链接该库。

## 库模块

| 文件 | 职责 |
|------|------|
| `cam_log.h` | 统一日志前缀 `edgeeye_cam:` |
| `cam_pipeline_config.h` | 管线常量（VPSS/VENC ID、PQ 路径等） |
| `cam_app_context.c/h` | 运行时全局状态 |
| `cam_pipeline_mode.c/h` | `dev_num` 判断、AE/AWB 等待 |
| `cam_vi_bringup.c/h` | SYS/VB/VI 初始化（`cam_vi_bringup_opts`） |
| `cam_isp_tuning.c/h` | 双摄 per-pipe PQ、`dual_plat_vi_init` |
| `cam_vpss_capture.c/h` | VPSS 组、VI 绑定、NV12 抓帧 |
| `cam_venc_encode.c/h` | H.264 VENC 与码流写盘 |
| `cam_rtsp_stream.c/h` | RTSP 服务与推流 |
| `cam_output_res.c/h` | 输出分辨率档位（1080p/720p/480p） |
| `cam_stream_run.c/h` | 产品 RTSP 管线（VPSS/VENC/推流） |
| `cam_sensor_setup.c/h` | 板端 `sensor_cfg.ini` / PQ 软链 |
| `edgeeye_cam.c` | **产品入口**（单摄/双摄 CLI） |
| `camera.mk` | 共享编译片段 |

## 构建

```bash
source /home/work/init_env.sh
cd /home/work/edgeeye-duos
make app    # → output/edgeeye_cam + output/my_cam_test
./deploy
```

## 产品用法（板上）

```bash
# 单摄 GC2083（J1）
edgeeye_cam --single gc2083

# 单摄 OV5647（J2）
edgeeye_cam --single ov5647

# 双摄
edgeeye_cam --dual

# 输出分辨率（VPSS 缩放，sensor 仍 1080p 采集）
edgeeye_cam --single gc2083 --res 720p
edgeeye_cam --dual -r 480p

# 可选：-P 8554  -v
```

| 档位 | 分辨率 | 码率约 |
|------|--------|--------|
| `1080p` / `high` | 1920×1080 | 4096 Kbps |
| `720p` / `medium` | 1280×720 | 2048 Kbps |
| `480p` / `low` | 640×480 | 1024 Kbps |

VI/ISP 始终在 sensor 原生 1080p 采集；VPSS 缩放到所选档位后送 VENC/RTSP。

配置文件模板：`configs/edgeeye_cam.conf` → 部署到 `/root/edgeeye_cam.conf`

或通过启动脚本（推荐，含媒体栈清理；无参数时读 `/root/edgeeye_cam.conf`）：

```bash
./start_my_cam_rtsp.sh
./start_my_cam_rtsp.sh dual --res 720p
```

## 开机自启

```bash
vi /root/edgeeye_cam.conf   # mode / port / res / record / web

./install_autostart.sh      # → run_edgeeye_stack.sh
reboot
```

完整栈：`run_edgeeye_stack.sh` = RTSP + 可选动检录像 + Web 快照（`:8080`）。

```bash
./stop_edgeeye_stack.sh
./health_check.sh
./verify_board.sh full
```

详见 [`docs/HOME_USER_GUIDE.md`](../../docs/HOME_USER_GUIDE.md)。

## Mac 预览

板子推流后，在 Mac 上：

```bash
# 一键：SSH 启动板子 + ffplay 弹窗
./scripts/preview_my_cam_rtsp_mac.sh --mode gc2083 --start-board
./scripts/preview_my_cam_rtsp_mac.sh --mode ov5647 --start-board
./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both --start-board

# 或手动
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam1   # dual only
```

## 测试

验收程序仍在 [`tests/camera/my_cam_test/`](../../tests/camera/my_cam_test/)，详见 [`tests/camera/TESTCASES.md`](../../tests/camera/TESTCASES.md)。

```bash
make test          # 宿主机静态检查
make test-board    # 板上冒烟
```

## 库 API 示例

```c
cam_vi_bringup_opts opts = {
    .enable_dual_vpss = CVI_TRUE,
    .vb_level = CAM_VB_LEVEL_VENC,
};
cam_sensor_setup(CAM_LAYOUT_SINGLE, CAM_SENSOR_GC2083);
cam_vi_bringup_init(&opts);
cam_stream_rtsp_setup();
cam_stream_rtsp_run(0, NULL);  /* 0 = 直到 SIGINT */
cam_vi_bringup_deinit();
```
