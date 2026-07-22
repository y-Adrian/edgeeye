#!/bin/sh
# test_18_ai_direct_frame.sh — AI 不经 RTSP 的 VPSS 直取帧检查
#
# 测试接口：edgeeye_cam --ai-direct；ai_grab_frame --source vpss
# 测试场景：宿主机静态检查（板上见 check_ai_direct_frame_board.sh）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_18_ai_direct_frame ==="

EXPORT="$ROOT/apps/camera/cam_ai_frame_export.c"
GRAB="$ROOT/apps/ai/ai_grab_frame.c"
CAM="$ROOT/apps/camera/edgeeye_cam.c"
COMMON="$ROOT/scripts/edgeeye_cam_common.sh"
START="$ROOT/scripts/start_my_cam_rtsp.sh"
CONF="$ROOT/configs/edgeeye_cam.conf"
CHECK="$ROOT/scripts/check_ai_direct_frame_board.sh"
DOC="$ROOT/docs/PRODUCT_LITE_AI.md"
FFBUILD="$ROOT/scripts/build_ffmpeg_cli.sh"

assert_file "$EXPORT"
assert_file "$ROOT/apps/camera/cam_ai_frame_export.h"
assert_file "$CHECK"
assert_grep_file 'CVI_VPSS_GetChnFrame' "$ROOT/apps/camera/cam_vpss_capture.c"
assert_grep_file 'CVI_VPSS_ReleaseChnFrame' "$ROOT/apps/camera/cam_vpss_capture.c"
assert_grep_file 'edgeeye_ai_frame.request' "$ROOT/apps/camera/cam_ai_frame_export.h"
assert_grep_file '--ai-direct' "$CAM"
assert_grep_file 'cam_ai_frame_export_start' "$CAM"
assert_grep_file '--ai-direct' "$START"
assert_grep_file '--source' "$GRAB"
assert_grep_file 'rawvideo' "$GRAB"
assert_grep_file 'AI_ARGS=.*--frame-source' "$COMMON"
assert_grep_file 'ai_frame_source=vpss' "$CONF"
assert_grep_file 'enable-demuxer=rawvideo' "$FFBUILD"
assert_grep_file 'CONFIG_RAWVIDEO_DEMUXER' "$FFBUILD"
assert_grep_file 'check_ai_direct_frame' "$DOC"
assert_grep_file 'check_ai_direct_frame_board.sh' "$ROOT/deploy"

test_summary
