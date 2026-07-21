#!/bin/sh
# check_lan_live_board.sh — 验证同局域网（WiFi）双路 HLS/RTSP 可访问
#
# Mac（板子已 WiFi + 已 run_edgeeye_stack 且 web=1）：
#   ./scripts/check_lan_live_board.sh
#   BOARD_LAN_IP=192.168.31.14 ./scripts/check_lan_live_board.sh
set -e

BOARD_USB="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
LAN_IP="${BOARD_LAN_IP:-}"
WARN=0

ok() { echo "[OK]   $1"; }
warn() { echo "[WARN] $1"; WARN=1; }
fail() { echo "[FAIL] $1"; exit 1; }

echo "=== LAN live check $(date) ==="

# 经 USB 查 wlan0 IP + 端口
REMOTE=$(ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_USB" '
set -e
WLAN=$(ip -4 addr show wlan0 2>/dev/null | awk "/inet /{print \$2}" | cut -d/ -f1 | head -1)
echo "WLAN_IP=${WLAN:-none}"
echo "WEB=$(grep -E "^web=" /root/edgeeye_cam.conf 2>/dev/null | head -1)"
echo "LIVE=$(grep -E "^web_live=" /root/edgeeye_cam.conf 2>/dev/null | head -1)"
if [ -f /tmp/edgeeye_cam_rtsp.pid ] && kill -0 "$(cat /tmp/edgeeye_cam_rtsp.pid)" 2>/dev/null; then
	echo "CAM=yes"
else
	echo "CAM=no"
fi
ls /root/web/hls/cam0.m3u8 /root/web/hls/cam1.m3u8 2>/dev/null | sed "s|^|HLSFILE=|" || true
netstat -ln 2>/dev/null | grep -E ":8554 |:8080 " | sed "s/^/LISTEN=/" || true
')

printf '%s\n' "$REMOTE"

WLAN=$(printf '%s\n' "$REMOTE" | sed -n 's/^WLAN_IP=//p' | head -1)
[ -n "$LAN_IP" ] || LAN_IP=$WLAN
[ -n "$LAN_IP" ] && [ "$LAN_IP" != "none" ] || fail "无 wlan0 IP — 先 ./scripts/setup_wifi_board.sh / check_wifi_board.sh"

echo "$REMOTE" | grep -q 'CAM=yes' || fail "edgeeye_cam 未运行 — 板上 ./run_edgeeye_stack.sh"
echo "$REMOTE" | grep -q 'web=1' || warn "conf 非 web=1，浏览器页可能未开"
echo "$REMOTE" | grep -q 'HLSFILE=.*/cam0.m3u8' || warn "尚无 cam0.m3u8（HLS remux 未就绪）"
echo "$REMOTE" | grep -q 'HLSFILE=.*/cam1.m3u8' || warn "尚无 cam1.m3u8"

echo "=== probe LAN IP $LAN_IP ==="

curl_ok() {
	url="$1"
	code=$(curl -sS -m 8 -o /tmp/edgeeye_lan_curl.out -w '%{http_code}' "$url" 2>/dev/null || echo 000)
	if [ "$code" = "200" ]; then
		ok "$url -> HTTP $code"
		return 0
	fi
	warn "$url -> HTTP $code"
	return 1
}

curl_ok "http://${LAN_IP}:8080/" || true
curl_ok "http://${LAN_IP}:8080/status.json" || true
if curl_ok "http://${LAN_IP}:8080/hls/cam0.m3u8"; then
	head -5 /tmp/edgeeye_lan_curl.out 2>/dev/null | sed 's/^/  | /'
fi
if curl_ok "http://${LAN_IP}:8080/hls/cam1.m3u8"; then
	head -5 /tmp/edgeeye_lan_curl.out 2>/dev/null | sed 's/^/  | /'
fi

# RTSP：有 ffprobe 则探一下
if command -v ffprobe >/dev/null 2>&1; then
	if ffprobe -rtsp_transport tcp -v quiet -show_entries stream=codec_name \
		-of default=nw=1 "rtsp://${LAN_IP}:8554/cam0" 2>/dev/null | grep -q codec_name; then
		ok "RTSP cam0 @ ${LAN_IP}:8554"
	else
		warn "RTSP cam0 probe 失败（可用 VLC 再试）"
	fi
	if ffprobe -rtsp_transport tcp -v quiet -show_entries stream=codec_name \
		-of default=nw=1 "rtsp://${LAN_IP}:8554/cam1" 2>/dev/null | grep -q codec_name; then
		ok "RTSP cam1 @ ${LAN_IP}:8554"
	else
		warn "RTSP cam1 probe 失败"
	fi
else
	warn "本机无 ffprobe，跳过 RTSP 探测"
fi

echo ""
echo "手机/电脑（同一 WiFi）打开："
echo "  http://${LAN_IP}:8080/"
echo "  rtsp://${LAN_IP}:8554/cam0"
echo "  rtsp://${LAN_IP}:8554/cam1"

if [ "$WARN" -ne 0 ]; then
	echo "=== 完成（有告警）==="
	exit 1
fi
echo "=== 全部通过：同网直播可用 ==="
exit 0
