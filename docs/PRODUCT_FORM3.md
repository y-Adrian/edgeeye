# 产品定义：形态三 — 家用双镜头安防节点

> **选定日期：** 2026-06-30  
> **硬件：** Milk-V Duo S · J1 GC2083 · J2 OV5647  
> **一句话：** 插电即用的小安防主机——**双路 RTSP 直播** + **动就录** + **开机自启** + **能长期挂着跑**。

---

## 1. 做完长什么样（用户视角）

### 物理形态

```text
[墙/角落]
   ├─ 镜头 A（J1 GC2083）— 例如门口
   ├─ 镜头 B（J2 OV5647）— 例如室内
   └─ 小盒子内：Duo S + microSD（录像）
        USB 连路由器/电脑（当前 192.168.42.1）
```

### 每天怎么用


| 你想做的事 | 怎么做                                       | 系统状态                       |
| ----- | ----------------------------------------- | -------------------------- |
| 看门口直播 | Mac/VLC → `rtsp://192.168.42.1:8554/cam0` | 上电即推流                      |
| 看室内直播 | 同上 → `.../cam1`                           | 与 cam0 **同时**可用            |
| 动就录   | 不用管                                       | 检测到运动 → SD 卡 `clips/*.mp4` |
| 断电重启  | 不用 SSH                                    | `S99debris_security` 自动拉起  |
| 担心挂了  | 偶尔看 `/tmp/debris_security.log`            | `health_check` 可巡检         |




### 形态三 ≠ 形态二 多出来的部分


| 能力                  | 形态二（demo） | **形态三（你家摄像头）**                |
| ------------------- | --------- | ----------------------------- |
| 双路同时 RTSP           | ✅ 必须      | ✅ 必须                          |
| GC2083 走统一 8554 栈   | 最好有       | **必须**（不能长期依赖 554 workaround） |
| 运动触发录像              | 可选        | **必须**                        |
| 开机自启                | 可选        | **必须**                        |
| `verify_board full` | 可选        | **必须**                        |
| 连续 6h 不崩            | 可选        | **必须**                        |


---



## 2. 验收清单（做完才算形态三）

复制到 PROJECT_STATUS 或 DEBUG 收口时逐项打勾：

### A. 双路直播（核心）

- [ ] **A1** 板上 `dev_num=2`，`cam_dual.json` 且 `"dev-num": 2`
- [ ] **A2** `8554/cam0`（GC2083）有画面，码率 ≥ 800 kb/s
- [ ] **A3** `8554/cam1`（OV5647）有画面，码率 ≥ 800 kb/s
- [ ] **A4** 两路 **同时** ffplay 30 分钟不崩
- [ ] **A5** PQ bin 策略确定（合并 bin **或** 已验证的妥协方案 + 文档说明）



### B. 安防栈

- [ ] **B1** `DEBRIS_DUAL=1 ./run_security.sh` 使用 **混搭** ini（`setup_mixed_dual_camera.sh`，非双 OV5647）
- [ ] **B2** `debris.ko` 与 RTSP 共存策略明确（`i2c_sensor_mode=0` + 文档）
- [ ] **B3** 运动触发能录至少一路 clip 到 SD（板载 ffmpeg 或 PC 拉流录制的既定方案）
- [ ] **B4** `health_check.sh` 全绿或已知 skip 有说明



### C. 插电即用

- [ ] **C1** `install_autostart.sh` 后 reboot，无需 SSH 即有 RTSP
- [ ] **C2** `verify_board.sh full` 通过
- [ ] **C3** 一页纸《家用说明》（两个 URL + 录像目录 + 重启办法）



### D. 长稳

- [ ] **D1** `stability_6h.sh` 完成，日志无致命错误
- [ ] **D2** 记录 CPU/内存/温度/码率基线（`docs/` 或 DEBUG 归档）

---



## 3. 分阶段路线图（建议顺序）

```text
M1 统一 RTSP（ISSUE-002）     GC2083 在 8554 出图
        ↓
M2 双路同时直播（ISSUE-003）  cam0 + cam1 混搭双摄
        ↓
M3 安防栈整合                 run_security + 混搭 + 录像
        ↓
M4 插电即用                   autostart + verify_board
        ↓
M5 长稳                       stability_6h → 形态三收口
```


| 里程碑    | 目标                          | 主要 ISSUE/文档              | 通过台词                 |
| ------ | --------------------------- | ------------------------ | -------------------- |
| **M1** | GC2083 走 `rtsp_server`/8554 | ISSUE-002                | 「cam0 单摄 8554 有画面」   |
| **M2** | 双路同时 RTSP                   | ISSUE-003（待建）            | 「两个 ffplay 同时有画面」    |
| **M3** | 动就录 + 全栈                    | 改 `run_security` 走 mixed | 「SD 卡里出现带时间戳的 mp4」   |
| **M4** | 自启                          | `install_autostart`      | 「reboot 后不 SSH 能看直播」 |
| **M5** | 长稳                          | `stability_6h`           | 「6 小时无崩溃」            |


**当前位置：** 单摄分别 OK；M1 未过（ISSUE-002 Step 1 待执行）；M2～M5 未开始。

---



## 4. 已知阻塞与对策


| 阻塞                                                 | 影响                    | 对策                                                     |
| -------------------------------------------------- | --------------------- | ------------------------------------------------------ |
| GC2083 @ 8554 空流                                   | M1/M2/M3 无法用统一栈       | ISSUE-002：`venc-bind-vpss: false` 等                    |
| 单 PQ bin 无法服务两路不同 sensor                           | M2 一路可能黑/偏色           | PQ Tool 合并 bin，或向 Milk-V 索取双摄 bin                      |
| `run_security` 默认 `setup_dual_camera.sh`（双 OV5647） | M3 配错 ini             | 改为 `setup_mixed_dual_camera.sh` / `rtsp_dual_mixed.sh` |
| `debris.ko` 与厂商管线抢 I2C                             | RTSP 与驱动共存失败          | RTSP 时 `i2c_sensor_mode=0`；或分时策略                       |
| 板子无 ffmpeg                                         | 板上 motion_recorder 跳过 | `install_ffmpeg_cli_board.sh` 或 PC 侧录制方案写进说明           |


---



## 5. Mac 端最终地址（形态三目标）

```text
门口 / J1 GC2083：  rtsp://192.168.42.1:8554/cam0
室内 / J2 OV5647：  rtsp://192.168.42.1:8554/cam1

建议：ffplay -rtsp_transport tcp <url>
录像：ffmpeg -rtsp_transport tcp -i <url> -c copy -t 30 clip.mp4
```

**过渡方案（M1 完成前）：** GC2083 临时仍可用 `554/h264`（`camera-test`），但 **不算形态三完成**。

---



## 6. 与 DEBUG_SESSION 的关系


| ISSUE                                 | 对应里程碑                        |
| ------------------------------------- | ---------------------------- |
| ISSUE-001                             | 已收口：8554 空流现象、554 workaround |
| ISSUE-002                             | **M1** — GC2083 @ 8554       |
| ISSUE-003（建议新建）                       | **M2** — 混搭双摄 cam0+cam1      |
| （M3～M5 可在形态三收口后建 ISSUE-004 或写在本文验收清单） |                              |


---



## 7. 下一步（立即行动）

1. 执行 **ISSUE-002 Step 1**（`cam0_gc2083_novpss.json`）→ 分析结果
2. M1 通过后新建 **ISSUE-003**，第一步：`/root/rtsp_dual_mixed.sh` + Mac 双路 ffplay
3. M2 通过后改 `run_security.sh` 双摄分支为 mixed 脚本

触发语示例：

```text
读 DEBUG_SESSION，分析 ISSUE-002 Step 1 结果
```

---



## 相关文档

- [ROADMAP.md](../ROADMAP.md) — 学习与 Phase 6 原意  
- [CAMERA_VERIFY.md](./CAMERA_VERIFY.md) — 阶段 F 双摄 PQ  
- [SINGLE_CAM_BRINGUP.md](./SINGLE_CAM_BRINGUP.md) — 单摄基础（已完成）  
- [DEPLOYMENT.md](./DEPLOYMENT.md) — deploy / autostart

