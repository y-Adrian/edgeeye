#!/bin/sh
# test_my_cam_test.sh — 阶段 2 验收：my_cam_test VI/ISP 初始化
#
# 用法：./test_my_cam_test.sh [gc2083|ov5647]
set -e

SENSOR="${1:-gc2083}"
BIN="${MY_CAM_TEST:-/root/my_cam_test}"
HOLD="${HOLD_SEC:-10}"
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

. "$DIR/my_cam_test_common.sh"
my_cam_resolve_sensor "$SENSOR"

if [ ! -x "$BIN" ]; then
	echo "missing $BIN — run: cd edgeeye-duos && make app && ./deploy"
	exit 1
fi

echo "=== test_my_cam_test phase 2: $SENSOR ==="

my_cam_stop_media
my_cam_link_sensor

LOG=/tmp/my_cam_test.log
"$BIN" -p 2 -s "$HOLD" >"$LOG" 2>&1
cat "$LOG"

grep -q "$PAT" "$LOG" || { echo "FAIL: no $PAT in log"; exit 1; }
grep -qi 'Init OK' "$LOG" || { echo "FAIL: no Init OK in log"; exit 1; }
grep -q 'PASSED (phase 2)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }

echo "=== PASSED phase 2 ($SENSOR) ==="
