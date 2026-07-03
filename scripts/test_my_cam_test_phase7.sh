#!/bin/sh
# test_my_cam_test_phase7.sh — 阶段 7 验收：双摄 VPSS 各抓一帧 NV12
set -e

BIN="${MY_CAM_TEST:-/root/my_cam_test}"
OUT0="${DUAL_CAM0_YUV:-/tmp/cam0.yuv}"
OUT1="${DUAL_CAM1_YUV:-/tmp/cam1.yuv}"
MIN=$((1920 * 1080 * 3 / 2))
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

. "$DIR/my_cam_test_common.sh"

if [ ! -x "$BIN" ]; then
	echo "missing $BIN"
	exit 1
fi

echo "=== test_my_cam_test phase 7: dual VPSS YUV ==="

my_cam_stop_media
my_cam_link_dual_sensor
rm -f "$OUT0" "$OUT1"
# tmpfs 满会导致 fwrite 失败（双摄 YUV 约 6MB+）
rm -f /tmp/*.yuv /tmp/*.h264 /tmp/my_cam_test_p*.log 2>/dev/null || true

LOG=/tmp/my_cam_test_p7.log
"$BIN" -p 7 >"$LOG" 2>&1
cat "$LOG"

grep -q 'dual VPSS capture OK' "$LOG" || { echo "FAIL: no dual capture line"; exit 1; }
grep -q 'PASSED (phase 7)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }
[ -f "$OUT0" ] || { echo "FAIL: missing $OUT0"; exit 1; }
[ -f "$OUT1" ] || { echo "FAIL: missing $OUT1"; exit 1; }

B0=$(wc -c <"$OUT0")
B1=$(wc -c <"$OUT1")
if [ "$B0" -lt "$MIN" ] || [ "$B1" -lt "$MIN" ]; then
	echo "FAIL: yuv too small cam0=$B0 cam1=$B1 (min $MIN)"
	exit 1
fi

echo "OK: $OUT0=$B0 bytes $OUT1=$B1 bytes"
echo "Mac: scp root@192.168.42.1:$OUT0 root@192.168.42.1:$OUT1 ."
echo "=== PASSED phase 7 (dual VPSS) ==="
