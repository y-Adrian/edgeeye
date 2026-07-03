#!/bin/sh
# test_07_stream_configs.sh — stream JSON 与 cam_dual 双摄配置静态校验
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_07_stream_configs ==="

CAM_DUAL="$ROOT/configs/stream/cam_dual.json"
CAM0="$ROOT/configs/stream/cam0.json"

assert_file "$CAM_DUAL"
assert_file "$CAM0"

assert_grep_file '"dev-num": 2' "$CAM_DUAL"
assert_grep_file '"compress-mode": "tile"' "$CAM_DUAL"
assert_grep_file '"rtsp-port": 8554' "$CAM_DUAL"

if command -v python3 >/dev/null 2>&1; then
	TESTS_RUN=$((TESTS_RUN + 1))
	if python3 -c "import json; json.load(open('$CAM_DUAL'))" 2>/dev/null; then
		echo "  ok: cam_dual.json valid JSON"
	else
		echo "  FAIL: cam_dual.json invalid JSON"
		TESTS_FAIL=$((TESTS_FAIL + 1))
	fi
	TESTS_RUN=$((TESTS_RUN + 1))
	if python3 -c "import json; json.load(open('$CAM0'))" 2>/dev/null; then
		echo "  ok: cam0.json valid JSON"
	else
		echo "  FAIL: cam0.json invalid JSON"
		TESTS_FAIL=$((TESTS_FAIL + 1))
	fi
else
	echo "  skip: python3 not found (JSON parse)"
fi

test_summary
