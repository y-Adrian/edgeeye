#!/bin/sh
# check_wifi_board.sh — 验证 Duo S WiFi 是否已关联并出网
#
# Mac：
#   ./scripts/check_wifi_board.sh
#   BOARD_IP=192.168.42.1 ./scripts/check_wifi_board.sh
#
# 板上：
#   ./check_wifi_board.sh --local
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
REMOTE=1
WARN=0

while [ $# -gt 0 ]; do
	case "$1" in
	--local) REMOTE=0; shift ;;
	-h|--help)
		sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*) echo "unknown arg: $1" >&2; exit 1 ;;
	esac
done

run() {
	if [ "$REMOTE" = "1" ]; then
		ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no \
			"$BOARD_USER@$BOARD_IP" "$@" || {
			echo "[FAIL] SSH $BOARD_USER@$BOARD_IP 失败（板子未连 / USB 网？）"
			exit 1
		}
	else
		sh -c "$*"
	fi
}

ok() { echo "[OK]   $1"; }
warn() { echo "[WARN] $1"; WARN=1; }
fail() { echo "[FAIL] $1"; exit 1; }

echo "=== WiFi check $(date) remote=$REMOTE ==="

OUT=$(run 'set -e
IFACE=wlan0
echo "=== link ==="
if ip link show "$IFACE" >/dev/null 2>&1; then
	ip link show "$IFACE"
	echo "EDGEEYE_WLAN0=yes"
else
	echo "EDGEEYE_WLAN0=no"
fi
echo "=== addr ==="
ip addr show "$IFACE" 2>&1 || true
echo "=== iw ==="
iw dev "$IFACE" link 2>&1 || iwconfig "$IFACE" 2>&1 || true
echo "=== conf ==="
if [ -f /etc/wpa_supplicant.conf ]; then
	grep -E "ssid=|key_mgmt=" /etc/wpa_supplicant.conf | sed "s/psk=.*/psk=\"***\"/"
	echo "EDGEEYE_WPACONF=yes"
else
	echo "EDGEEYE_WPACONF=no"
fi
echo "=== procs ==="
if ps w 2>/dev/null | grep -q "[w]pa_supplicant"; then
	ps w 2>/dev/null | grep "[w]pa_supplicant"
	echo "EDGEEYE_WPA=yes"
else
	echo "EDGEEYE_WPA=no"
fi
echo "=== ping4 ==="
if ping -c 3 -W 3 8.8.8.8 >/tmp/edgeeye_wifi_ping4.txt 2>&1; then
	cat /tmp/edgeeye_wifi_ping4.txt
	echo "EDGEEYE_PING4=ok"
else
	cat /tmp/edgeeye_wifi_ping4.txt 2>/dev/null || true
	echo "EDGEEYE_PING4=fail"
fi
echo "=== ping_dns ==="
if ping -c 2 -W 3 www.baidu.com >/tmp/edgeeye_wifi_pingdns.txt 2>&1; then
	cat /tmp/edgeeye_wifi_pingdns.txt
	echo "EDGEEYE_PINGDNS=ok"
else
	cat /tmp/edgeeye_wifi_pingdns.txt 2>/dev/null || true
	echo "EDGEEYE_PINGDNS=fail"
fi
')

printf '%s\n' "$OUT"

echo "=== summary ==="
echo "$OUT" | grep -qE '^EDGEEYE_WLAN0=no$' && fail "wlan0 不存在（天线/驱动？）"
echo "$OUT" | grep -qE '^EDGEEYE_WLAN0=yes$' || fail "wlan0 状态未知"
echo "$OUT" | grep -qE '^EDGEEYE_WPACONF=no$' && warn "无 wpa_supplicant.conf"
echo "$OUT" | grep -qE '^EDGEEYE_WPA=no$' && warn "wpa_supplicant 未运行"

# 有 inet 且非 127
if echo "$OUT" | grep -E 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -vq '127.0.0.1'; then
	IP=$(echo "$OUT" | grep -E 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -v '127.0.0.1' | head -1 | awk '{print $2}')
	ok "wlan0 有 IP ($IP)"
else
	fail "wlan0 无 IPv4（关联失败或 DHCP 失败）"
fi

if echo "$OUT" | grep -q 'Not associated' ; then
	fail "未关联 AP"
fi
if echo "$OUT" | grep -qiE 'Connected to|Access Point:|^[[:space:]]*SSID:'; then
	ok "已关联 AP"
else
	warn "未能从 iw/iwconfig 确认关联（若已有 IP 可忽略）"
fi

if echo "$OUT" | grep -qE '^EDGEEYE_PING4=fail$'; then
	warn "ping 8.8.8.8 失败（路由/防火墙？）"
elif echo "$OUT" | grep -qE '^EDGEEYE_PING4=ok$'; then
	ok "外网 ICMP (8.8.8.8)"
else
	warn "ping 8.8.8.8 结果不明"
fi

if echo "$OUT" | grep -qE '^EDGEEYE_PINGDNS=fail$'; then
	warn "DNS/域名 ping 失败"
elif echo "$OUT" | grep -qE '^EDGEEYE_PINGDNS=ok$'; then
	ok "DNS 解析可用 (www.baidu.com)"
else
	warn "DNS ping 结果不明"
fi

if [ "$WARN" -ne 0 ]; then
	echo "=== 完成（有告警）==="
	exit 1
fi
echo "=== 全部通过：WiFi 可用 ==="
exit 0
