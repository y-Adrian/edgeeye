#!/bin/sh
# test_09_motion_record_config.sh — 动检录像配置与 motion_recorder 源码检查
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_09_motion_record_config ==="

CONF="$ROOT/configs/edgeeye_cam.conf"
COMMON="$ROOT/scripts/edgeeye_cam_common.sh"
REC="$ROOT/apps/motion/motion_recorder.c"

assert_file "$CONF"
assert_file "$COMMON"
assert_file "$REC"

assert_grep_file 'motion_source=rtsp' "$CONF"
assert_grep_file 'autostart=0' "$CONF"
assert_grep_file 'web=0' "$CONF"
assert_grep_file 'EDGEEYE_AUTOSTART' "$COMMON"
assert_grep_file 'edgeeye_apply_autostart' "$COMMON"
assert_grep_file 'motion_threshold=' "$CONF"
assert_grep_file 'motion_interval_sec=' "$CONF"
assert_grep_file 'EDGEEYE_MOTION_SOURCE' "$COMMON"
assert_grep_file 'MOTION_SOURCE=' "$COMMON"
assert_grep_file 'MOTION_THRESHOLD' "$COMMON"
assert_grep_file 'run_rtsp_loop' "$REC"
assert_grep_file 'grab_jpeg_probe' "$REC"

test_summary
