#!/bin/sh
# test_my_cam_test_phase3.sh — 阶段 3 验收：VPSS 抓一帧 NV12
#
# 用法：./test_my_cam_test_phase3.sh [gc2083|ov5647]
set -e

SENSOR="${1:-gc2083}"
BIN="${MY_CAM_TEST:-/root/my_cam_test}"
OUT="${YUV_OUT:-/tmp/frame.yuv}"
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

. "$DIR/my_cam_test_common.sh"
my_cam_resolve_sensor "$SENSOR"

if [ ! -x "$BIN" ]; then
	echo "missing $BIN"
	exit 1
fi

echo "=== test_my_cam_test phase 3: $SENSOR ==="

my_cam_stop_media
my_cam_link_sensor
rm -f "$OUT"

LOG=/tmp/my_cam_test_p3.log
"$BIN" -p 3 -o "$OUT" >"$LOG" 2>&1
cat "$LOG"

grep -q 'saved .* NV12' "$LOG" || { echo "FAIL: no save line"; exit 1; }
grep -q 'PASSED (phase 3)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }
[ -f "$OUT" ] || { echo "FAIL: missing $OUT"; exit 1; }

BYTES=$(wc -c <"$OUT")
MIN=$((YUV_W * YUV_H * 3 / 2))
if [ "$BYTES" -lt "$MIN" ]; then
	echo "FAIL: $OUT too small ($BYTES < $MIN)"
	exit 1
fi

echo "OK: $OUT size=$BYTES bytes (expect ~${MIN} for ${YUV_W}x${YUV_H} NV12)"
echo "Mac preview: scp root@192.168.42.1:$OUT . && ffplay -f rawvideo -pixel_format nv12 -video_size ${YUV_W}x${YUV_H} frame.yuv"
echo "=== PASSED phase 3 ($SENSOR) ==="
