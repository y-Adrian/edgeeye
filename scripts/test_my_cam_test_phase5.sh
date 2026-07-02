#!/bin/sh
# test_my_cam_test_phase5.sh — 阶段 5 验收：VPSS → VENC → RTSP
#
# 用法：./test_my_cam_test_phase5.sh [gc2083|ov5647]
set -e

SENSOR="${1:-gc2083}"
BIN="${MY_CAM_TEST:-/root/my_cam_test}"
PORT="${RTSP_PORT:-8554}"
URL="${RTSP_URL:-cam0}"
STREAM_SEC="${STREAM_SEC:-20}"
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

. "$DIR/my_cam_test_common.sh"
my_cam_resolve_sensor "$SENSOR"

if [ ! -x "$BIN" ]; then
	echo "missing $BIN"
	exit 1
fi

echo "=== test_my_cam_test phase 5: $SENSOR ==="

my_cam_stop_media
my_cam_link_sensor

LOG=/tmp/my_cam_test_p5.log
"$BIN" -p 5 -s "$STREAM_SEC" -P "$PORT" -u "$URL" >"$LOG" 2>&1 &
PID=$!

sleep 5
if netstat -ln 2>/dev/null | grep -q ":$PORT "; then
	echo "OK: RTSP port $PORT listening"
elif ss -ln 2>/dev/null | grep -q ":$PORT"; then
	echo "OK: RTSP port $PORT listening"
else
	echo "WARN: cannot confirm port $PORT (netstat/ss missing?)"
fi

wait "$PID"
RC=$?
cat "$LOG"

if [ "$RC" -ne 0 ]; then
	echo "FAIL: my_cam_test exited $RC"
	exit 1
fi

grep -q 'RTSP streamed' "$LOG" || { echo "FAIL: no RTSP streamed line"; exit 1; }
grep -q 'PASSED (phase 5)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }

echo "Mac preview: ffplay -rtsp_transport tcp rtsp://192.168.42.1:$PORT/$URL"
echo "=== PASSED phase 5 ($SENSOR) ==="
