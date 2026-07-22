#!/bin/sh
# test_13_ai_event_log.sh — AI 事件日志骨架源码/文档检查（宿主机）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_13_ai_event_log ==="

SRC="$ROOT/apps/ai/ai_event_log.c"
CONF="$ROOT/configs/edgeeye_cam.conf"
MK="$ROOT/apps/Makefile"
COMMON="$ROOT/scripts/edgeeye_cam_common.sh"
DOC="$ROOT/docs/PRODUCT_LITE_AI.md"

assert_file "$SRC"
assert_file "$ROOT/apps/ai/README.md"
assert_grep_file 'events.ndjson' "$SRC"
assert_grep_file '--inject' "$SRC"
assert_grep_file 'person' "$SRC"
assert_grep_file 'ai_event_log' "$MK"
assert_grep_file 'EDGEEYE_AI' "$COMMON"
assert_grep_file '^ai=0' "$CONF"
assert_grep_file 'ai_classes=person' "$CONF"
assert_grep_file 'ai_event_log' "$DOC"

test_summary
