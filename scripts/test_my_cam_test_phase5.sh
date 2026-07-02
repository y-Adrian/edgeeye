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

case "$SENSOR" in
    gc2083|GC2083|j1|J1)
        INI=/mnt/data/sensor_cfg_GC2083.ini
        PQ=cvi_sdr_bin_GC2083
        ;;
    ov5647|OV5647|j2|J2)
        INI=/mnt/data/sensor_cfg_OV5647_J2.ini
        PQ=cvi_sdr_bin_OV5647.bin
        ;;
    *)
        echo "usage: $0 [gc2083|ov5647]"
        exit 1
        ;;
esac

if [ ! -x "$BIN" ]; then
    echo "missing $BIN"
    exit 1
fi

echo "=== test_my_cam_test phase 5: $SENSOR ==="

for p in $(ps | grep -E 'sample_vi|rtsp_server|my_cam_test|camera-test' | grep -v grep | awk '{print $1}'); do
    kill "$p" 2>/dev/null || true
done
sleep 2
rmmod debris 2>/dev/null || true

ln -sf "$INI" /mnt/data/sensor_cfg.ini
ln -sf "$PQ" /mnt/cfg/param/cvi_sdr_bin

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

wait "$PID" || true
cat "$LOG"

grep -q 'RTSP streamed' "$LOG" || { echo "FAIL: no RTSP streamed line"; exit 1; }
grep -q 'PASSED (phase 5)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }

echo "Mac preview: ffplay -rtsp_transport tcp rtsp://192.168.42.1:$PORT/$URL"
echo "=== PASSED phase 5 ($SENSOR) ==="
