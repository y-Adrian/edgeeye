#!/bin/sh
# test_04_source_layout.sh — cam_* 库模块与测试目录布局
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
CAM="$ROOT/apps/camera"
TEST="$ROOT/tests/camera/my_cam_test"
MK_LIB="$CAM/Makefile"
MK_TEST="$TEST/Makefile"

. "$DIR/lib_assert.sh"

echo "=== test_04_source_layout ==="

for f in \
	cam_app_context.h \
	cam_log.h \
	cam_pipeline_config.h \
	cam_isp_tuning.h \
	cam_vi_bringup.h \
	cam_vpss_capture.h \
	cam_venc_encode.h \
	cam_rtsp_stream.h
do
	assert_file "$CAM/$f"
done

for f in \
	cam_app_context.c \
	cam_isp_tuning.c \
	cam_vi_bringup.c \
	cam_vpss_capture.c \
	cam_venc_encode.c \
	cam_rtsp_stream.c \
	cam_pipeline_mode.c
do
	assert_file "$CAM/$f"
	assert_grep_file "$(basename "$f")" "$CAM/camera.mk"
done

assert_file "$CAM/camera.mk"
assert_file "$TEST/my_cam_test.c"
assert_file "$TEST/cam_test_phases.c"
assert_file "$TEST/cam_test_config.h"
assert_grep_file 'my_cam_test.c' "$MK_TEST"
assert_grep_file 'cam_test_phases.c' "$MK_TEST"
assert_grep_file 'CAM_LIB_SRCS' "$CAM/camera.mk"

assert_grep_file 'CAM_PQ_BIN_GC2083' "$CAM/cam_pipeline_config.h"
assert_grep_file 'cam_vi_bringup_init' "$CAM/cam_vi_bringup.h"
assert_grep_file 'cam_isp_dual_plat_vi_init' "$CAM/cam_isp_tuning.h"
assert_grep_file 'CAM_DUAL_CAM0_YUV' "$TEST/cam_test_config.h"

test_summary
