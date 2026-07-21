#!/bin/sh
# test_16_ai_person_record.sh — 人检测触发录像脚本检查
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_16_ai_person_record ==="

DET="$ROOT/scripts/ai_person_detect.sh"
CHK="$ROOT/scripts/check_ai_person_record_board.sh"
DOC="$ROOT/docs/PRODUCT_LITE_AI.md"

assert_file "$DET"
assert_file "$CHK"
assert_grep_file '--record' "$DET"
assert_grep_file 'record_clip' "$DET"
assert_grep_file 'clip-sec' "$DET"
assert_grep_file 'simulate-person' "$DET"
assert_grep_file '--record' "$DOC"
assert_grep_file 'check_ai_person_record' "$DOC"
assert_grep_file 'ai_person_detect.sh' "$ROOT/deploy"
assert_grep_file 'check_ai_person_record_board.sh' "$ROOT/deploy"

test_summary
