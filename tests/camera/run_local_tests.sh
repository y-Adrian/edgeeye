#!/bin/sh
# run_local_tests.sh — 宿主机/Docker 外均可跑的 my_cam_test 静态测试套件
#
# 用法：从仓库根目录
#   tests/camera/run_local_tests.sh
#   make test
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"

FAIL=0
PASS=0

run_one() {
	name=$(basename "$1")
	echo ""
	if sh "$1"; then
		PASS=$((PASS + 1))
	else
		echo ">>> FAILED: $name"
		FAIL=$((FAIL + 1))
	fi
}

echo "=============================================="
echo " EdgeEye camera local tests"
echo " ROOT=$ROOT"
echo "=============================================="

chmod +x "$DIR"/test_*.sh "$DIR"/run_*.sh 2>/dev/null || true

for t in \
	"$DIR/test_01_script_syntax.sh" \
	"$DIR/test_02_common_functions.sh" \
	"$DIR/test_03_sensor_configs.sh" \
	"$DIR/test_04_source_layout.sh" \
	"$DIR/test_05_deploy_manifest.sh" \
	"$DIR/test_06_golden_logs.sh" \
	"$DIR/test_07_stream_configs.sh" \
	"$DIR/test_08_suite_profiles.sh" \
	"$DIR/test_09_motion_record_config.sh" \
	"$DIR/test_10_web_hls_config.sh" \
	"$DIR/test_11_wifi_docs.sh" \
	"$DIR/test_12_lite_gc2083_config.sh" \
	"$DIR/test_13_ai_event_log.sh" \
	"$DIR/test_14_ai_grab_frame.sh" \
	"$DIR/test_15_ai_person_detect.sh"
do
	run_one "$t"
done

echo ""
echo "=============================================="
echo " Local summary: $PASS passed, $FAIL failed"
echo "=============================================="

if [ "$FAIL" -ne 0 ]; then
	exit 1
fi

echo "All local camera tests passed."
