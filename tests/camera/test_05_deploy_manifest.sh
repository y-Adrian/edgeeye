#!/bin/sh
# test_05_deploy_manifest.sh — deploy 须包含产品栈与验收脚本
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_05_deploy_manifest ==="

DEPLOY="$ROOT/deploy"
assert_file "$DEPLOY"

for s in \
	run_edgeeye_stack.sh \
	stop_edgeeye_stack.sh \
	edgeeye_cam_common.sh \
	serve_edgeeye_web.sh \
	edgeeye_hls.sh \
	edgeeye_http_server.py \
	edgeeye_snapshots.sh \
	health_check.sh \
	install_autostart.sh \
	test_my_cam_test.sh \
	test_my_cam_test_phase.sh \
	test_my_cam_test_phase3.sh \
	test_my_cam_test_phase4.sh \
	test_my_cam_test_phase5.sh \
	test_my_cam_test_phase6.sh \
	test_my_cam_test_phase7.sh \
	test_my_cam_test_phase8.sh \
	test_my_cam_test_dual.sh \
	test_my_cam_test_suite.sh \
	start_my_cam_rtsp.sh \
	stop_my_cam_rtsp.sh \
	preview_my_cam_rtsp_mac.sh \
	my_cam_test_common.sh
do
	assert_grep_file "$s" "$DEPLOY"
	assert_file "$ROOT/scripts/$s"
done

assert_grep_file 'edgeeye_deploy_ffmpeg' "$DEPLOY"
assert_grep_file 'ffmpeg-riscv64-static' "$DEPLOY"

test_summary
