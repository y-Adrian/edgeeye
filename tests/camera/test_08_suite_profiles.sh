#!/bin/sh
# test_08_suite_profiles.sh — suite / e2e 脚本结构与 profile 名检查
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_08_suite_profiles ==="

assert_file "$ROOT/scripts/test_my_cam_test_suite.sh"
assert_file "$ROOT/scripts/test_my_cam_test_dual.sh"
assert_file "$ROOT/scripts/start_my_cam_rtsp.sh"
assert_file "$ROOT/scripts/preview_my_cam_rtsp_mac.sh"
assert_file "$ROOT/tests/camera/run_e2e.sh"
assert_file "$ROOT/tests/camera/lib_board.sh"

assert_grep_file '--profile' "$ROOT/scripts/test_my_cam_test_suite.sh"
assert_grep_file 'smoke' "$ROOT/scripts/test_my_cam_test_suite.sh"
assert_grep_file 'dual-unified' "$ROOT/scripts/test_my_cam_test_suite.sh"
assert_grep_file 'docker run' "$ROOT/tests/camera/run_e2e.sh"
assert_grep_file 'test_my_cam_test_suite.sh' "$ROOT/tests/camera/run_e2e.sh"
assert_grep_file 'start_my_cam_rtsp.sh' "$ROOT/deploy"
assert_grep_file 'preview_my_cam_rtsp_mac.sh' "$ROOT/deploy"
assert_grep_file 'test_my_cam_test_dual.sh' "$ROOT/deploy"
assert_grep_file 'test_my_cam_test_suite.sh' "$ROOT/deploy"
assert_grep_file 'test-e2e' "$ROOT/Makefile"

test_summary
