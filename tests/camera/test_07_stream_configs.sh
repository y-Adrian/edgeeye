#!/bin/sh
# test_07_sensor_deploy.sh — sensor ini 部署包静态校验
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_07_sensor_deploy ==="

DUAL="$ROOT/configs/sensor/sensor_cfg_GC2083_OV5647_dual.ini"
DEPLOY_INI="$ROOT/output/stream/sensor_cfg_GC2083_OV5647_dual.ini"

assert_file "$DUAL"
assert_grep_file 'dev_num = 2' "$DUAL"
assert_grep_file 'GCORE_GC2083' "$DUAL"
assert_grep_file 'OV_OV5647' "$DUAL"

if [ -f "$DEPLOY_INI" ]; then
	assert_grep_file 'dev_num = 2' "$DEPLOY_INI"
else
	echo "  skip: $DEPLOY_INI (run make app first)"
fi

test_summary
