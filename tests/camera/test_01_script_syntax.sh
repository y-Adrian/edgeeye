#!/bin/sh
# test_01_script_syntax.sh — 验收脚本 shell 语法检查（无需板子）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_01_script_syntax ==="

for f in \
	"$ROOT/scripts/my_cam_test_common.sh" \
	"$ROOT/scripts/edgeeye_cam_common.sh" \
	"$ROOT/scripts/run_edgeeye_stack.sh" \
	"$ROOT/scripts/stop_edgeeye_stack.sh" \
	"$ROOT/scripts/start_my_cam_rtsp.sh" \
	"$ROOT/scripts/stop_my_cam_rtsp.sh" \
	"$ROOT/scripts/serve_edgeeye_web.sh" \
	"$ROOT/scripts/edgeeye_snapshots.sh" \
	"$ROOT/scripts/health_check.sh" \
	"$ROOT/scripts/install_autostart.sh" \
	"$ROOT/scripts/test_my_cam_test.sh" \
	"$ROOT/scripts/test_my_cam_test_phase.sh" \
	"$ROOT/scripts/test_my_cam_test_phase3.sh" \
	"$ROOT/scripts/test_my_cam_test_phase4.sh" \
	"$ROOT/scripts/test_my_cam_test_phase5.sh" \
	"$ROOT/scripts/test_my_cam_test_phase6.sh" \
	"$ROOT/scripts/test_my_cam_test_phase7.sh" \
	"$ROOT/scripts/test_my_cam_test_phase8.sh" \
	"$ROOT/scripts/test_my_cam_test_dual.sh" \
	"$ROOT/scripts/test_my_cam_test_suite.sh" \
	"$ROOT/scripts/preview_my_cam_rtsp_mac.sh" \
	"$ROOT/tests/camera/run_local_tests.sh" \
	"$ROOT/tests/camera/run_board_tests.sh" \
	"$ROOT/tests/camera/run_e2e.sh"
do
	TESTS_RUN=$((TESTS_RUN + 1))
	if sh -n "$f" 2>/dev/null; then
		echo "  ok: sh -n $(basename "$f")"
	else
		echo "  FAIL: sh -n $(basename "$f")"
		TESTS_FAIL=$((TESTS_FAIL + 1))
	fi
done

test_summary
