#!/bin/sh
# test_15_ai_person_detect.sh — 人检测编排脚本存在性检查
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_15_ai_person_detect ==="

DET="$ROOT/scripts/ai_person_detect.sh"
INST="$ROOT/scripts/install_tdl_libs_board.sh"
CHK="$ROOT/scripts/check_ai_person_detect_board.sh"
DOC="$ROOT/docs/PRODUCT_LITE_AI.md"

assert_file "$DET"
assert_file "$INST"
assert_file "$CHK"
assert_grep_file 'mobiledetv2-pedestrian' "$DET"
assert_grep_file 'sample_img_det' "$DET"
assert_grep_file 'ai_grab_frame' "$DET"
assert_grep_file 'ai_event_log' "$DET"
assert_grep_file 'libcvi_tdl_app.so' "$INST"
assert_grep_file 'ai_person_detect' "$DOC"
assert_grep_file 'ai_person_detect' "$ROOT/deploy"

test_summary
