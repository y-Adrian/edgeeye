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
# 板上多为 BusyBox grep：须 -E 才支持 .* ；或拆成关键字 + Init OK 计数
if grep -Eq 'GC2083.*Init OK' "$LOG" 2>/dev/null; then
	:
elif grep -q 'GC2083' "$LOG" && grep -q 'Init OK' "$LOG"; then
	:
else
	echo "FAIL: no GC2083 Init OK"
	exit 1
fi
if grep -Eq 'OV5647.*Init OK' "$LOG" 2>/dev/null; then
	:
elif grep -q 'OV5647' "$LOG" && grep -q 'Init OK' "$LOG"; then
	:
else
	echo "FAIL: no OV5647 Init OK"
	exit 1
fi
INIT_CNT=$(grep -c 'Init OK' "$LOG" 2>/dev/null || echo 0)
if [ "$INIT_CNT" -lt 2 ]; then
	echo "FAIL: expected >=2 Init OK lines, got $INIT_CNT"
	exit 1
fi
grep -q 'PQ loaded pipe0' "$LOG" || { echo "FAIL: no PQ pipe0"; exit 1; }
grep -q 'PQ loaded pipe1' "$LOG" || { echo "FAIL: no PQ pipe1"; exit 1; }
grep -q 'dual VI/ISP OK' "$LOG" || { echo "FAIL: no dual VI OK line"; exit 1; }
grep -q 'PASSED (phase 6)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }

echo "=== PASSED phase 6 (dual VI) ==="
