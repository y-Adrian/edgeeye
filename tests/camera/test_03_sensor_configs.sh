#!/bin/sh
# test_03_sensor_configs.sh — 仓库内 sensor_cfg 与双摄 ini 静态校验
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_03_sensor_configs ==="

DUAL="$ROOT/configs/sensor/sensor_cfg_GC2083_OV5647_dual.ini"
OV_DUAL="$ROOT/configs/sensor/sensor_cfg_OV5647_dual.ini"

assert_file "$DUAL"
assert_file "$OV_DUAL"

assert_grep_file 'dev_num = 2' "$DUAL"
assert_grep_file 'GCORE_GC2083' "$DUAL"
assert_grep_file 'OV_OV5647' "$DUAL"
assert_grep_file 'bus_id = 3' "$DUAL"
assert_grep_file 'bus_id = 2' "$DUAL"

assert_grep_file '\[sensor2\]' "$DUAL"

# J1=I2C3 / J2=I2C2 与 HARDWARE_NOTES 一致
assert_grep_file 'sns_i2c_addr = 37' "$DUAL"
assert_grep_file 'sns_i2c_addr = 36' "$DUAL"

test_summary
