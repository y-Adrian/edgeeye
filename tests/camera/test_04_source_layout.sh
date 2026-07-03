#!/bin/sh
# test_04_source_layout.sh — cam_* 模块与 Makefile 一致性
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
MK="$ROOT/apps/camera/Makefile"
CAM="$ROOT/apps/camera"

. "$DIR/lib_assert.sh"

echo "=== test_04_source_layout ==="

for f in \
	cam_app_context.h \
	cam_pipeline_config.h \
	cam_isp_tuning.h \
	cam_vi_bringup.h \
	cam_vpss_capture.h \
	cam_venc_encode.h \
	cam_rtsp_stream.h \
	cam_test_phases.h
do
	assert_file "$CAM/$f"
done

for f in \
	my_cam_test.c \
	cam_app_context.c \
	cam_isp_tuning.c \
	cam_vi_bringup.c \
	cam_vpss_capture.c \
	cam_venc_encode.c \
	cam_rtsp_stream.c \
	cam_test_phases.c
do
	assert_file "$CAM/$f"
	assert_grep_file "$(basename "$f")" "$MK"
done

assert_grep_file 'CAM_SRCS' "$MK"
assert_grep_file 'cam_test_phases.c' "$MK"

# 路径常量与头文件一致
assert_grep_file 'CAM_DUAL_CAM0_YUV' "$CAM/cam_pipeline_config.h"
assert_grep_file 'CAM_PQ_BIN_GC2083' "$CAM/cam_pipeline_config.h"
assert_grep_file 'cam_vi_bringup_init' "$CAM/cam_vi_bringup.h"
assert_grep_file 'cam_isp_dual_plat_vi_init' "$CAM/cam_isp_tuning.h"

test_summary
