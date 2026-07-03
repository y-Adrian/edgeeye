#!/bin/sh
# test_02_common_functions.sh — my_cam_test_common.sh 解析逻辑（宿主机）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_02_common_functions ==="

. "$ROOT/scripts/my_cam_test_common.sh"

my_cam_resolve_sensor gc2083
assert_eq "$PAT" "GC2083" "gc2083 -> PAT"
assert_eq "$YUV_W" "1920" "gc2083 YUV_W"
assert_eq "$YUV_H" "1080" "gc2083 YUV_H"
assert_match "GC2083" "$INI" "gc2083 ini path"

my_cam_resolve_sensor ov5647
assert_eq "$PAT" "OV5647" "ov5647 -> PAT"
assert_match "OV5647" "$INI" "ov5647 ini path"

my_cam_resolve_sensor j2
assert_eq "$PAT" "OV5647" "j2 alias -> OV5647"

if my_cam_resolve_sensor unknown_sensor 2>/dev/null; then
	TESTS_RUN=$((TESTS_RUN + 1))
	echo "  FAIL: unknown sensor should fail"
	TESTS_FAIL=$((TESTS_FAIL + 1))
else
	TESTS_RUN=$((TESTS_RUN + 1))
	echo "  ok: unknown sensor rejected"
fi

# dual resolve/link 依赖板上 /mnt/data，宿主机仅校验仓库 ini（详见 test_03 / TC-06）
assert_grep_file 'dev_num = 2' "$ROOT/configs/sensor/sensor_cfg_GC2083_OV5647_dual.ini"

test_summary
