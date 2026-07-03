#!/bin/sh
# test_05_deploy_manifest.sh — deploy 须包含全部 my_cam_test 验收脚本
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_05_deploy_manifest ==="

DEPLOY="$ROOT/deploy"
assert_file "$DEPLOY"

for s in \
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
	my_cam_test_common.sh
do
	assert_grep_file "$s" "$DEPLOY"
	assert_file "$ROOT/scripts/$s"
done

test_summary
