#!/bin/sh
# test_my_cam_test_phase8.sh — 阶段 8 验收：双摄 VENC 各写 H.264
set -e

BIN="${MY_CAM_TEST:-/root/my_cam_test}"
OUT0="${DUAL_CAM0_H264:-/tmp/cam0.h264}"
OUT1="${DUAL_CAM1_H264:-/tmp/cam1.h264}"
MIN=1024
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

. "$DIR/my_cam_test_common.sh"

if [ ! -x "$BIN" ]; then
	echo "missing $BIN"
	exit 1
fi

echo "=== test_my_cam_test phase 8: dual VENC H264 ==="

my_cam_stop_media
my_cam_link_dual_sensor
rm -f "$OUT0" "$OUT1"
rm -f /tmp/*.yuv /tmp/*.h264 /tmp/my_cam_test_p*.log 2>/dev/null || true

LOG=/tmp/my_cam_test_p8.log
"$BIN" -p 8 >"$LOG" 2>&1
cat "$LOG"

grep -q 'start save from IDR' "$LOG" || { echo "FAIL: no IDR slice saved"; exit 1; }
grep -q 'dual VENC capture OK' "$LOG" || { echo "FAIL: no dual VENC capture line"; exit 1; }
grep -q 'PASSED (phase 8)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }
[ -f "$OUT0" ] || { echo "FAIL: missing $OUT0"; exit 1; }
[ -f "$OUT1" ] || { echo "FAIL: missing $OUT1"; exit 1; }

B0=$(wc -c <"$OUT0")
B1=$(wc -c <"$OUT1")
if [ "$B0" -lt "$MIN" ] || [ "$B1" -lt "$MIN" ]; then
	echo "FAIL: h264 too small cam0=$B0 cam1=$B1 (min $MIN)"
	exit 1
fi

echo "OK: $OUT0=$B0 bytes $OUT1=$B1 bytes"
echo "Mac preview:"
echo "  scp root@192.168.42.1:$OUT0 root@192.168.42.1:$OUT1 ."
echo "  ffplay -f h264 -video_size 1920x1080 cam0.h264"
echo "  ffplay -f h264 -video_size 1920x1080 cam1.h264"
echo "=== PASSED phase 8 (dual VENC) ==="
