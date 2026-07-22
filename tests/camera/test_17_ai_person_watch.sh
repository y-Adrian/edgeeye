#!/bin/sh
# test_17_ai_person_watch.sh — 循环人检 / cooldown / 栈 AI 启动检查
#
# 接口：ai_person_detect.sh --watch；edgeeye_start_ai；conf ai_interval_sec
# 场景：宿主机静态检查（板上见 check_ai_person_watch_board.sh）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_17_ai_person_watch ==="

DET="$ROOT/scripts/ai_person_detect.sh"
CHK="$ROOT/scripts/check_ai_person_watch_board.sh"
COMMON="$ROOT/scripts/edgeeye_cam_common.sh"
STACK="$ROOT/scripts/run_edgeeye_stack.sh"
STOP="$ROOT/scripts/stop_edgeeye_stack.sh"
CONF="$ROOT/configs/edgeeye_cam.conf"
DOC="$ROOT/docs/PRODUCT_LITE_AI.md"

assert_file "$DET"
assert_file "$CHK"
assert_grep_file '--watch' "$DET"
assert_grep_file '--interval' "$DET"
assert_grep_file '--cooldown' "$DET"
assert_grep_file 'max-rounds' "$DET"
assert_grep_file 'edgeeye_start_ai' "$COMMON"
assert_grep_file 'edgeeye_stop_ai' "$COMMON"
assert_grep_file 'edgeeye_start_ai' "$STACK"
assert_grep_file 'edgeeye_stop_ai' "$STOP"
assert_grep_file '^ai=0' "$CONF"
assert_grep_file 'ai_interval_sec=20' "$CONF"
assert_grep_file 'ai_record=0' "$CONF"
assert_grep_file 'EDGEEYE_AI_INTERVAL_SEC:-20' "$COMMON"
assert_grep_file 'EDGEEYE_AI_RECORD:-0' "$COMMON"
assert_grep_file '--watch' "$DOC"
assert_grep_file 'check_ai_person_watch' "$DOC"
assert_grep_file 'ai_person_detect.sh' "$ROOT/deploy"
assert_grep_file 'check_ai_person_watch_board.sh' "$ROOT/deploy"

test_summary
