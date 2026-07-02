#!/bin/sh
# test_my_cam_test_phase4.sh — 阶段 4 验收：VPSS → VENC 写 H.264
#
# 用法：./test_my_cam_test_phase4.sh [gc2083|ov5647]
set -e

SENSOR="${1:-gc2083}"
BIN="${MY_CAM_TEST:-/root/my_cam_test}"
OUT="${H264_OUT:-/tmp/frame.h264}"
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

. "$DIR/my_cam_test_common.sh"
my_cam_resolve_sensor "$SENSOR"

if [ ! -x "$BIN" ]; then
	echo "missing $BIN"
	exit 1
fi

echo "=== test_my_cam_test phase 4: $SENSOR ==="

my_cam_stop_media
my_cam_link_sensor
rm -f "$OUT"

LOG=/tmp/my_cam_test_p4.log
"$BIN" -p 4 -o "$OUT" >"$LOG" 2>&1
cat "$LOG"

grep -q 'saved H264' "$LOG" || { echo "FAIL: no saved H264 line"; exit 1; }
grep -q 'PASSED (phase 4)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }
[ -f "$OUT" ] || { echo "FAIL: missing $OUT"; exit 1; }

BYTES=$(wc -c <"$OUT")
if [ "$BYTES" -lt 1024 ]; then
	echo "FAIL: $OUT too small ($BYTES bytes)"
	exit 1
fi

echo "OK: $OUT size=$BYTES bytes"
echo "Mac preview: scp root@192.168.42.1:$OUT . && ffplay frame.h264"
echo "=== PASSED phase 4 ($SENSOR) ==="
