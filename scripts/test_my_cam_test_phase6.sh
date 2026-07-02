#!/bin/sh
# test_my_cam_test_phase6.sh — 阶段 6 验收：双摄 VI/ISP 初始化
#
# 用法：./test_my_cam_test_phase6.sh
# 须已链 sensor_cfg_GC2083_OV5647_dual.ini（dev_num=2）
set -e

BIN="${MY_CAM_TEST:-/root/my_cam_test}"
HOLD="${HOLD_SEC:-10}"
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

. "$DIR/my_cam_test_common.sh"

if [ ! -x "$BIN" ]; then
	echo "missing $BIN"
	exit 1
fi

echo "=== test_my_cam_test phase 6: dual VI/ISP ==="

my_cam_stop_media
my_cam_link_dual_sensor

LOG=/tmp/my_cam_test_p6.log
"$BIN" -p 6 -s "$HOLD" >"$LOG" 2>&1
cat "$LOG"

grep -q 'dev_num=2' "$LOG" || { echo "FAIL: dev_num not 2"; exit 1; }
grep -qi 'GC2083.*Init OK' "$LOG" || { echo "FAIL: no GC2083 Init OK"; exit 1; }
grep -qi 'OV5647.*Init OK' "$LOG" || { echo "FAIL: no OV5647 Init OK"; exit 1; }
grep -q 'dual VI/ISP OK' "$LOG" || { echo "FAIL: no dual VI OK line"; exit 1; }
grep -q 'PASSED (phase 6)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }

echo "=== PASSED phase 6 (dual VI) ==="
