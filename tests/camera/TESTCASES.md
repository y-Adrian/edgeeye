# my_cam_test 测试用例归档

## 测试分层

| 层级 | 入口 | 环境 | 说明 |
|------|------|------|------|
| **L0 本地静态** | `make test` / `tests/camera/run_local_tests.sh` | macOS / CI | 脚本语法、ini、Makefile、fixture 日志，**无需板子** |
| **L1 板上验收** | `scripts/test_my_cam_test_phase*.sh` | Milk-V Duo S | 真实 VI/ISP/VPSS/VENC/RTSP |
| **L2 板上批量** | `tests/camera/run_board_tests.sh` | SSH `192.168.42.1` | 远程跑 suite（默认 smoke） |
| **L3 Mac 一键 E2E** | `make test-e2e` / `tests/camera/run_e2e.sh` | Docker 编译 + deploy + SSH | 编译→部署→板上矩阵验收；失败自动拉 log |

---

## L0 本地用例（`tests/camera/`）

| 编号 | 脚本 | 测试场景 |
|------|------|----------|
| LT-01 | `test_01_script_syntax.sh` | 全部 `test_my_cam_test*.sh` / `my_cam_test_common.sh` `sh -n` 语法 |
| LT-02 | `test_02_common_functions.sh` | `my_cam_resolve_sensor` gc2083/ov5647/别名；未知 sensor 拒绝；dual ini 解析 |
| LT-03 | `test_03_sensor_configs.sh` | `configs/sensor/sensor_cfg_GC2083_OV5647_dual.ini` dev_num=2、两路 sensor、I2C 地址 |
| LT-04 | `test_04_source_layout.sh` | `cam_*` 模块文件存在且列入 `apps/camera/Makefile` |
| LT-05 | `test_05_deploy_manifest.sh` | `deploy` 包含 phase 2～8 验收脚本 |
| LT-06 | `test_06_golden_logs.sh` | fixture 日志满足板上验收 grep 模式 |
| LT-07 | `test_07_stream_configs.sh` | 混搭双摄 sensor ini 与 `make` 部署包 |
| LT-11 | `test_11_wifi_docs.sh` | WiFi 文档/脚本/示例 conf 存在性 |

### 运行

```bash
cd edgeeye-duos
make test
# 或
tests/camera/run_local_tests.sh
```

---

## L1 板上用例（phase 2～8）

公共前置（各脚本内已调用）：

- `my_cam_stop_media` — 停媒体进程，避免 Grp occupied
- 单摄：`my_cam_link_sensor` — 链 `sensor_cfg.ini` + `cvi_sdr_bin`
- 双摄：`my_cam_link_dual_sensor` — 链 dual ini，检查两路 PQ bin 存在

| 编号 | 阶段 | 脚本 | 传感器 | 测试接口 | 通过条件 |
|------|------|------|--------|----------|----------|
| TC-02 | 2 | `test_my_cam_test.sh` | gc2083 / ov5647 | VI/ISP init | log 含 sensor 名、`Init OK`、`PASSED (phase 2)` |
| TC-03 | 3 | `test_my_cam_test_phase3.sh` | gc2083 / ov5647 | VPSS `GetChnFrame` | NV12 文件 ≥ 1920×1080×1.5 B |
| TC-04 | 4 | `test_my_cam_test_phase4.sh` | gc2083 / ov5647 | VENC 写 H.264 | 文件 ≥ 1KB，log `saved H264` |
| TC-05 | 5 | `test_my_cam_test_phase5.sh` | gc2083 / ov5647 | RTSP 推流 | 端口监听，帧数 ≥ 30 |
| TC-06 | 6 | `test_my_cam_test_phase6.sh` | 双摄 | dual VI/ISP + per-pipe PQ | `dev_num=2`、两路 `Init OK`、`PQ loaded pipe0/1`、`PASSED (phase 6)` |
| TC-07 | 7 | `test_my_cam_test_phase7.sh` | 双摄 | dual VPSS NV12 | `/tmp/cam0.yuv` + `cam1.yuv` 各 ≥ 3MB |
| TC-08 | 8 | `test_my_cam_test_phase8.sh` | 双摄 | dual VENC H.264 | 两路 H.264 ≥ 1KB，log 含 `IDR` |

统一入口：

```bash
scripts/test_my_cam_test_phase.sh <2-8> [gc2083|ov5647]
```

### 板上运行示例

```bash
make app && ./deploy
ssh root@192.168.42.1 'reboot'   # 建议先重启清媒体栈

ssh root@192.168.42.1 '/root/test_my_cam_test_phase.sh 6'
ssh root@192.168.42.1 '/root/test_my_cam_test_phase.sh 7'
```

### Mac 批量（L2 / L3）

```bash
# L3 一键（推荐）：Docker 编译 + deploy + 板上 smoke
make test-e2e

# 全矩阵（单摄 gc2083 2～5 + 双摄统一 2～5 + legacy 6～8）
tests/camera/run_e2e.sh --profile full --reboot

# 仅已部署产物，远程 smoke
tests/camera/run_board_tests.sh

# 板上直接跑（SSH 进板子后）
/root/test_my_cam_test_suite.sh --profile dual --phases 3,4,5
/root/test_my_cam_test_suite.sh --list
```

#### Suite profile 一览

| profile | 内容 |
|---------|------|
| `smoke`（默认） | 单摄 gc2083 p2,p3 + 双摄统一 p3 |
| `single` | 单摄 gc2083 phase 2～5 |
| `single-all` | gc2083 + ov5647 各跑 2～5 |
| `dual` | 双摄统一 phase 2～5（`-p 3/4/5` 自动两路） |
| `dual-legacy` | 旧脚本 phase 6/7/8 |
| `full` | 上述 single + dual + dual-legacy |

### 板端启动 + Mac 预览

```bash
# 1) deploy 到板子
make app && ./deploy

# 2) 板子上启动 RTSP（单摄 / 双摄）
ssh root@192.168.42.1 '/root/start_my_cam_rtsp.sh gc2083'
ssh root@192.168.42.1 '/root/start_my_cam_rtsp.sh dual'

# 3) Mac 上预览
./scripts/preview_my_cam_rtsp_mac.sh --mode gc2083
./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both

# 也可由 Mac 一条命令先 SSH 启动板子，再本机预览
./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both --start-board
```

---

## 功能覆盖矩阵

| 功能点 | L0 | TC |
|--------|----|-----|
| 验收脚本可部署 | LT-05 | — |
| sensor_cfg 双摄配置 | LT-03 | TC-06～08 |
| per-pipe PQ 加载 | LT-06 | TC-06～08 |
| 单摄 VI/ISP | — | TC-02 |
| VPSS 抓帧 | LT-04 | TC-03, TC-07 |
| H.264 文件 | LT-06 | TC-04, TC-08 |
| RTSP | LT-07 | TC-05 |
| 双摄在线 VPSS | LT-06 | TC-07, TC-08 |
| 源码模块完整性 | LT-04 | — |

---

## Fixture 日志

`tests/camera/fixtures/` 存放代表性通过日志，供 LT-06 回归 grep 模式；板上 log 格式变更时同步更新 fixture。

---

## 故障排查速查

| 现象 | 建议 |
|------|------|
| `Grp(0) is occupied` | `reboot` 或 `my_cam_stop_media` |
| `/tmp` 满导致 fwrite 失败 | phase7/8 脚本已 `rm /tmp/*.yuv`；手动 `df /tmp` |
| phase 6 PQ 无 pipe1 | 检查 `cvi_sdr_bin_OV5647.bin` 是否存在 |
| 画面灰/无内容 | 先 phase 7 看 `Y mean`；对比 fixture phase7 |
