# Duo S WiFi（板子上网）

给 Milk-V Duo S 连接家用 **WPA/WPA2-PSK** WiFi，使板子可访问外网。  
USB 网（`192.168.42.1`）仍可同时用于 SSH 调试。

官方背景：[Milk-V Duo S — WIFI configuration](https://milkv.io/docs/duo/getting-started/duos)。

## 前提

1. **天线已插上**（IPEX 座）
2. 路由器为普通家用热点（**非**企业/校园 WPA-EAP；板载 `wpa_supplicant` 通常不支持 EAP）
3. 能经 USB 登录板子：`ssh root@192.168.42.1`

## 一键配置（推荐）

在 Mac 仓库根目录（板子已 USB 联网）：

```bash
cd edgeeye-duos
./scripts/setup_wifi_board.sh --ssid '你的WiFi名' --psk '你的密码'

# 开机自动连接（写入 /mnt/system/auto.sh）
./scripts/setup_wifi_board.sh --ssid '你的WiFi名' --psk '你的密码' --autostart
```

已在板上时：

```bash
./setup_wifi_board.sh --ssid '你的WiFi名' --psk '你的密码' --local
```

脚本会：

- 写入 `/etc/wpa_supplicant.conf`（覆盖前备份为 `.bak.*`）
- 启动 `wpa_supplicant` + `udhcpc`
- 打印 `wlan0` 地址

模板见 [`configs/wpa_supplicant.conf.example`](../configs/wpa_supplicant.conf.example)。**勿把真实密码提交进 git。**

## 手动配置

```bash
ssh root@192.168.42.1

# 确认网卡
ip link show wlan0

vi /etc/wpa_supplicant.conf
```

内容：

```text
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1
update_config=1

network={
  ssid="YOUR_WIFI_SSID"
  psk="YOUR_WIFI_PASSWORD"
  key_mgmt=WPA-PSK
}
```

```bash
killall wpa_supplicant 2>/dev/null
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
udhcpc -i wlan0 -q
ip addr show wlan0
```

## 验证 WiFi 是否可用

### 方式 A：仓库脚本（推荐）

```bash
# Mac 经 USB 远程检查
./scripts/check_wifi_board.sh

# 板上本地
./check_wifi_board.sh --local
```

通过标准：

| 检查 | 期望 |
|------|------|
| `wlan0` 存在 | 有接口 |
| IPv4 | 如 `192.168.x.x/24`（非 127.0.0.1） |
| 关联 AP | `iw` / `iwconfig` 显示 Connected / SSID |
| `ping 8.8.8.8` | 通 |
| `ping www.baidu.com` | 通（DNS） |

退出码 `0` = 全部通过；非 0 = 有 FAIL/WARN。

### 方式 B：板上手工

```bash
ip addr show wlan0
iw dev wlan0 link          # 或 iwconfig wlan0
ping -c 3 8.8.8.8
ping -c 2 www.baidu.com
```

有 `inet`、已关联、外网 ping 通即可判定 WiFi 正常。

### 方式 C：经 WiFi SSH

记下 `wlan0` 的 IP（如 `192.168.31.14`），在 Mac：

```bash
ssh root@192.168.31.14
```

能登入即说明 WiFi 管理面可用（密码默认多为 `milkv`，若改过用自己的）。

## 与 EdgeEye 的关系

| 用途 | 地址 |
|------|------|
| USB 调试 / 原文档默认 | `192.168.42.1` |
| WiFi 访问 RTSP / 网页 | `rtsp://<wlan0-IP>:8554/cam0`、`http://<wlan0-IP>:8080/` |

USB 与 WiFi 可并存；产品栈本身不依赖 WiFi。

## 同 WiFi 看双路直播（局域网）

前提：板子已连 WiFi，且：

```ini
# /root/edgeeye_cam.conf
web=1
web_live=hls
record=0
```

```bash
./run_edgeeye_stack.sh
ip -4 addr show wlan0    # 记下 IP，例如 192.168.31.14
```

**同一路由器下的手机/电脑**（不必插 USB）打开：

```text
http://<wlan0-IP>:8080/
```

或 VLC：

```text
rtsp://<wlan0-IP>:8554/cam0
rtsp://<wlan0-IP>:8554/cam1
```

一键验证（Mac）：

```bash
./scripts/check_lan_live_board.sh
# 或指定 IP：
BOARD_LAN_IP=192.168.31.14 ./scripts/check_lan_live_board.sh
```

跨公网 / 不同网络见文档说明：需 VPN（如 Tailscale），不是默认能力。

## 常见问题

| 现象 | 处理 |
|------|------|
| 无 `wlan0` | 插天线；`lsmod \| grep aic`；`dmesg \| grep -iE 'wlan\|aic'` |
| 有进程但无 IP | 等数秒再 `udhcpc -i wlan0 -q`；确认密码/SSID |
| 企业网连不上 | 需 WPA-EAP，当前镜像通常不支持 |
| 开机断网 | 用 `--autostart` 或检查 `/mnt/system/auto.sh` |
| 想换网 | 再跑一遍 `setup_wifi_board.sh`（会备份旧 conf） |
| 同 WiFi 但手机打不开直播 | 小米路由等可能开了 **AP 隔离/无线隔离**，关掉后重试；或先用 USB `http://192.168.42.1:8080/` 确认栈正常 |

## 部署脚本到板子

```bash
./deploy
# 或单独：
scp scripts/setup_wifi_board.sh scripts/check_wifi_board.sh root@192.168.42.1:/root/
chmod +x /root/setup_wifi_board.sh /root/check_wifi_board.sh
```
