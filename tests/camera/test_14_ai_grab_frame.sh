#!/bin/sh
# test_14_ai_grab_frame.sh — AI 取帧源码检查（宿主机）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_14_ai_grab_frame ==="

SRC="$ROOT/apps/ai/ai_grab_frame.c"
DOC="$ROOT/docs/PRODUCT_LITE_AI.md"
CHK="$ROOT/scripts/check_ai_grab_frame_board.sh"

assert_file "$SRC"
assert_file "$CHK"
assert_grep_file 'scale=' "$SRC"
assert_grep_file '--once' "$SRC"
assert_grep_file '--source' "$SRC"
assert_grep_file 'source=vpss' "$SRC"
assert_grep_file '8554/cam0' "$SRC"
assert_grep_file '448' "$SRC"
assert_grep_file 'ai_grab_frame' "$DOC"
assert_grep_file 'ai_grab_frame' "$ROOT/apps/Makefile"

test_summary
