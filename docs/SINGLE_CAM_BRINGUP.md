# 单摄逐步调通指南

> 本板硬件：**J1 = GC2083**（`i2c-3 / 0x37`），**J2 = OV5647**（`i2c-2 / 0x36`）。  
> 双摄试失败后，务必先 **reboot**，再按本文 **一次只测一颗头**。  
> 相关归档：[CAMERA_VERIFY.md](./CAMERA_VERIFY.md)

**状态（用户确认）：** **OV5647（J2）单摄已调通**，Mac 可正常显示图像。  
日志可能出现 `pqbin md5 mismatch`，不影响出图。

---

## 通则

| 规则 | 原因 |
|------|------|
| 单摄时 `dev_num = 1` | 只启用一路传感器 |
| 使用 `cam0.json` 启动 | 单路 RTSP，URL 为 `cam0` |
| 勿用 `cam_dual.json` / `*_dual.ini` | 避免 `dev_num=2` 与单摄 JSON 不匹配导致黑屏 |
| `sensor_cfg.ini` 与 `cvi_sdr_bin` 必须配对 | PQ 调参错误 → mismatch / 黑屏 |
| 启动前先停 `rtsp_server` | 旧进程占用 VI/ISP，新配置不生效 |
| 启动前 `rmmod debris` | 学习驱动与厂商管线抢传感器 |

Mac 预览地址（两颗头单摄时相同）：

```text
rtsp://192.168.42.1:8554/cam0
```

建议传输：`ffplay -rtsp_transport tcp ...` 或 VLC 选 TCP。

---

## 脚本一键（deploy 后）

```bash
chmod +x /root/test_single_cam.sh
/root/test_single_cam.sh gc2083    # 步骤一
# Mac 确认有画面后再：
/root/test_single_cam.sh ov5647    # 步骤二
```

手动逐步调试见下文。

---

## 步骤 0：重启（双摄失败后强烈建议）

```bash
reboot
```

等待 30～60 秒再 SSH 登录。VI/ISP 僵死后，只改 ini 往往无法恢复。

---

## 步骤一：J1 GC2083（官方模组）

### 1.1 停掉旧服务

```bash
for _p in $(ps | grep rtsp_server | grep -v grep | awk '{print $1}'); do kill $_p; done
```

| 作用 | 查找并结束所有 `rtsp_server` 进程（板上无 `pkill`） |

```bash
rm -f /tmp/rtsp_server.pid
```

| 作用 | 删除 pid 文件，防止 `start_rtsp.sh` 误判「已在运行」而拒绝启动 |

```bash
rmmod debris 2>/dev/null
```

| 作用 | 卸载 `debris.ko`（未加载则静默）；避免与厂商传感器初始化冲突 |

```bash
sleep 2
```

| 作用 | 等待进程退出、驱动释放 |

---

### 1.2 配置传感器（sensor_cfg）

```bash
ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
```

| 作用 | 软链到 GC2083 单摄配置：`dev_num=1`，`bus_id=3`（J1） |

```bash
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini
```

| 作用 | 核对必须为 `dev_num = 1`、`GCORE_GC2083...`、`bus_id = 3` |

---

### 1.3 配置 ISP 调参（PQ bin）

```bash
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
```

| 作用 | ISP 只读 `cvi_sdr_bin`；链到 GC2083 出厂 bin |

**关于 `2083 != 2053` mismatch：** 日志可能出现，阶段 B 已验证 **仍可出图**，属 PQ 元数据警告，单摄 GC2083 **可先忽略**。

---

### 1.4 确认硬件

```bash
i2cdetect -y 3
```

| 作用 | 扫描 J1 所用 I2C 总线；应看到 **`37`**（0x37） |

---

### 1.5 启动 RTSP

```bash
: > /tmp/rtsp_server.log
```

| 作用 | 清空日志，便于查看本次启动 |

```bash
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
```

| 作用 | 指定厂商库路径（`start_rtsp.sh` 内也会设置） |

```bash
/root/stream/start_rtsp.sh /root/stream/cam0.json
```

| 作用 | 后台启动 `rtsp_server`：读 `sensor_cfg` → VI/ISP/VPSS/VENC → RTSP `:8554/cam0` |

```bash
sleep 16
```

| 作用 | 等待传感器与编码管线就绪 |

---

### 1.6 板上自检

```bash
kill -0 $(cat /tmp/rtsp_server.pid) && echo "rtsp 存活" || echo "rtsp 已退出"
netstat -ln | grep 8554
grep -iE 'GC2083|Init OK|mismatch|fail|error' /tmp/rtsp_server.log | tail -10
```

| 检查项 | 通过标准 |
|--------|----------|
| 进程 | `rtsp 存活` |
| 端口 | `8554` 在监听 |
| 日志 | `GC2083 1080P ... Init OK` |

---

### 1.7 Mac 验证

```bash
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 10 gc2083.mp4
ffprobe -show_entries stream=bit_rate,width,height -of default=nw=1 gc2083.mp4
ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
```

| 检查项 | 通过标准 |
|--------|----------|
| 码率 | 约 **1～2 Mbps**（阶段 B 约 1.77M） |
| 画面 | 可见实景（非全黑） |

黑屏时码率常 **&lt;100 kbps**。

---

## 步骤二：J2 OV5647（树莓派模组）

**前提：** 步骤一 Mac 已有画面。必须先停步骤一的 RTSP，再测 OV5647。

### 2.1 停掉上一路

与 [1.1](#11-停掉旧服务) 相同（`kill rtsp` → `rm pid` → `rmmod debris` → `sleep 2`）。

---

### 2.2 sensor_cfg

```bash
ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini
```

| 作用 | 单摄 OV5647 / J2：`dev_num=1`，`bus_id=2` |

---

### 2.3 PQ bin（必须配对）

```bash
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
```

| 作用 | OV5647 sensor id **22087**；若仍用 GC2083 bin 会 `22087 vs 2053` 且易黑屏 |

---

### 2.4 硬件

```bash
i2cdetect -y 2
```

| 作用 | J2 总线；应看到 **`36`**（0x36） |

---

### 2.5 启动与自检

与 [1.5～1.6](#15-启动-rtsp) 相同（`cam0.json`，日志改 grep `OV5647`）。

| 检查项 | 通过标准 |
|--------|----------|
| 日志 | `OV5647 ... Init OK` |
| mismatch | **不应**出现 `22087 vs 2053`；`pqbin md5 mismatch` 可为警告 |

---

### 2.6 Mac 验证

```bash
ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 10 ov5647.mp4
ffprobe -show_entries stream=bit_rate -of default=nw=1 ov5647.mp4
```

| 检查项 | 通过标准 |
|--------|----------|
| 码率 | 约 **3～5 Mbps**（曾测 ~4.2M） |

---

## 配置对照表

| 项目 | GC2083（J1） | OV5647（J2） |
|------|----------------|----------------|
| `sensor_cfg` | `sensor_cfg_GC2083.ini` | `sensor_cfg_OV5647_J2.ini` |
| `bus_id` | 3 | 2 |
| `cvi_sdr_bin` → | `cvi_sdr_bin_GC2083` | `cvi_sdr_bin_OV5647.bin` |
| I2C 扫描 | `i2cdetect -y 3` → `37` | `i2cdetect -y 2` → `36` |
| Init 日志 | `GC2083 ... Init OK` | `OV5647 ... Init OK` |
| mismatch | `2083/2053` 可忽略 | 不应 `22087/2053` |
| 参考码率 | ~1.7 Mbps | ~4 Mbps |
| RTSP | `rtsp://192.168.42.1:8554/cam0` | 同上 |

---

## mismatch 说明

| 日志 | 摄像头 | 是否必须消除 |
|------|--------|----------------|
| `mwSns:22087 != pqBinSns:2053` | OV5647 | **是** → 链 `cvi_sdr_bin_OV5647.bin` |
| `mwSns:2083 != pqBinSns:2053` | GC2083 | **否**（警告；阶段 B 有画面时也存在） |

彻底消除 GC2083 的 2083/2053 需 PQ Tool 重生成 bin 或向 Milk-V 索取，见 [CAMERA_VERIFY.md §3](./CAMERA_VERIFY.md)。

---

## 故障速查

| 现象 | 优先检查 |
|------|----------|
| Mac 连不上 | `kill -0 pid` 是否 DEAD；`netstat \| grep 8554` |
| 能连无画面 | `dev_num` 是否为 1；PQ bin 是否配对；`ffprobe` 码率 |
| OV5647 mismatch 2053 | `ls -la /mnt/cfg/param/cvi_sdr_bin` 是否 OV5647.bin |
| 双摄后两路都坏 | **reboot** 后从步骤一重来 |
| `i2cdetect` 无设备 | 排线、插座、是否插对接口（J1/J2） |

诊断脚本：

```bash
/root/rtsp_diagnose.sh
```

---

## 相关文件

| 路径 | 说明 |
|------|------|
| `scripts/test_single_cam.sh` | 单摄自动检查 |
| `scripts/rtsp_recover.sh` | 单摄急救 |
| `scripts/select_pq_bin.sh` | 切换 PQ bin |
| `app/stream/cam0.json` | 单摄 RTSP 配置 |
| `duo-sdk/.../param/cvi_sdr_bin_*` | PQ bin 源文件 |

---

## 下一步

两颗头单摄均通过后，再考虑混搭双摄（需 `dev-num:2` 的 `cam_dual.json` + 合并 PQ bin），见 [CAMERA_VERIFY.md 阶段 F](./CAMERA_VERIFY.md)。
