#!/bin/sh
# setup_wifi_board.sh — 配置 Duo S 连接家用 WiFi（WPA-PSK）
#
# 用法（Mac，经 USB 网 ssh）：
#   ./scripts/setup_wifi_board.sh --ssid 'MyWiFi' --psk 'password'
#   ./scripts/setup_wifi_board.sh --ssid 'MyWiFi' --psk 'password' --autostart
#
# 用法（已在板上）：
#   ./setup_wifi_board.sh --ssid 'MyWiFi' --psk 'password' --local
#
# 验证：./scripts/check_wifi_board.sh
#
# 注意：真实密码勿提交 git；仅支持家用 WPA/WPA2-PSK（非企业 EAP）
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
SSID=""
PSK=""
AUTOSTART=0
REMOTE=1
TMPCONF=""

usage() {
	sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
}

while [ $# -gt 0 ]; do
	case "$1" in
	--ssid) SSID="$2"; shift 2 ;;
	--psk) PSK="$2"; shift 2 ;;
	--autostart) AUTOSTART=1; shift ;;
	--local) REMOTE=0; shift ;;
	-h|--help) usage ;;
	*) echo "unknown arg: $1" >&2; usage ;;
	esac
done

[ -n "$SSID" ] && [ -n "$PSK" ] || {
	echo "需要 --ssid 与 --psk" >&2
	usage
}

# 拒绝配置里危险字符，避免破坏 conf
case "$SSID" in
*\"*|*\`*)
	echo "ssid 请勿包含双引号或反引号" >&2
	exit 1
	;;
esac
case "$PSK" in
*\"*|*\`*)
	echo "psk 请勿包含双引号或反引号" >&2
	exit 1
	;;
esac

write_conf() {
	path="$1"
	cat >"$path" <<EOF
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1
update_config=1

network={
	ssid="$SSID"
	psk="$PSK"
	key_mgmt=WPA-PSK
}
EOF
}

start_wifi_cmds='set -e
IFACE=wlan0
i=0
while [ $i -lt 30 ]; do
	ip link show "$IFACE" >/dev/null 2>&1 && break
	sleep 1
	i=$((i + 1))
done
ip link show "$IFACE" >/dev/null 2>&1 || {
	echo "ERROR: wlan0 不存在 — 检查天线 / aic8800"
	lsmod 2>/dev/null | grep -i aic || true
	exit 1
}
if [ -f /etc/wpa_supplicant.conf ]; then
	cp -a /etc/wpa_supplicant.conf "/etc/wpa_supplicant.conf.bak.$(date +%s 2>/dev/null || echo old)" || true
fi
killall wpa_supplicant 2>/dev/null || true
sleep 1
wpa_supplicant -B -i "$IFACE" -c /etc/wpa_supplicant.conf
sleep 3
udhcpc -i "$IFACE" -q -n 2>/dev/null || udhcpc -i "$IFACE" -q 2>/dev/null || true
sleep 2
echo "--- wlan0 ---"
ip addr show "$IFACE"
'

autostart_cmds='set -e
AUTO=/mnt/system/auto.sh
mkdir -p /mnt/system
touch "$AUTO"
chmod +x "$AUTO"
if grep -q "EdgeEye: auto connect WiFi" "$AUTO" 2>/dev/null; then
	echo "autostart already present in $AUTO"
	exit 0
fi
cat >> "$AUTO" << "EOF"

# EdgeEye: auto connect WiFi (WPA-PSK)
interface=wlan0
i=0
while [ $i -lt 60 ]; do
	ip link show "$interface" >/dev/null 2>&1 && break
	sleep 1
	i=$((i + 1))
done
if ip link show wlan0 >/dev/null 2>&1; then
	killall wpa_supplicant 2>/dev/null || true
	wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
	udhcpc -i wlan0 -b 2>/dev/null || true
fi
EOF
echo "autostart appended to $AUTO"
'

echo "=== setup WiFi ssid=$SSID remote=$REMOTE ==="

if [ "$REMOTE" = "1" ]; then
	TMPCONF=$(mktemp /tmp/edgeeye_wpa.XXXXXX)
	write_conf "$TMPCONF"
	scp -o ConnectTimeout=8 -o StrictHostKeyChecking=no \
		"$TMPCONF" "$BOARD_USER@$BOARD_IP:/etc/wpa_supplicant.conf"
	rm -f "$TMPCONF"
	ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no \
		"$BOARD_USER@$BOARD_IP" "$start_wifi_cmds"
	if [ "$AUTOSTART" = "1" ]; then
		ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no \
			"$BOARD_USER@$BOARD_IP" "$autostart_cmds"
	fi
else
	write_conf /etc/wpa_supplicant.conf
	sh -c "$start_wifi_cmds"
	if [ "$AUTOSTART" = "1" ]; then
		sh -c "$autostart_cmds"
	fi
fi

echo ""
echo "配置已写入板上 /etc/wpa_supplicant.conf"
echo "验证: ./scripts/check_wifi_board.sh   或板上 ./check_wifi_board.sh"
