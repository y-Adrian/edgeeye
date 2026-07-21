#!/bin/sh
# test_12_lite_gc2083_config.sh — EdgeEye Lite 单摄 GC2083 默认配置检查
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_12_lite_gc2083_config ==="

CONF="$ROOT/configs/edgeeye_cam.conf"
DOC="$ROOT/docs/PRODUCT_LITE_AI.md"

assert_file "$CONF"
assert_file "$DOC"
assert_grep_file 'mode=gc2083' "$CONF"
assert_grep_file 'web=0' "$CONF"
assert_grep_file 'GC2083' "$DOC"
assert_grep_file '人检测' "$DOC"
assert_grep_file '本地日志' "$DOC"

# 默认不得是 dual
if grep -qE '^mode=dual$' "$CONF"; then
	echo "  FAIL: default mode must not be dual" >&2
	exit 1
fi
echo "  ok: default mode is not dual"

test_summary
