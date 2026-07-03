/*
 * cam_test_config.h — my_cam_test 验收专用常量与辅助
 */
#ifndef CAM_TEST_CONFIG_H
#define CAM_TEST_CONFIG_H

#include "cam_vi_bringup.h"

#define CAM_TEST_LOG_TAG           "my_cam_test"

#define CAM_DEFAULT_HOLD_SEC       10
#define CAM_DEFAULT_PHASE          2
#define CAM_DEFAULT_YUV_PATH       "/tmp/frame.yuv"
#define CAM_DEFAULT_H264_PATH      "/tmp/frame.h264"
#define CAM_DEFAULT_RTSP_PORT      8554
#define CAM_DEFAULT_RTSP_URL       "cam0"
#define CAM_DEFAULT_STREAM_SEC     30

#define CAM_VENC_SAVE_TARGET_STREAMS 10
#define CAM_VENC_SAVE_MAX_ATTEMPTS 40
#define CAM_VENC_SAVE_MIN_BYTES    1024
#define CAM_RTSP_MIN_FRAMES        30

#define CAM_DUAL_CAM0_YUV          "/tmp/cam0.yuv"
#define CAM_DUAL_CAM1_YUV          "/tmp/cam1.yuv"
#define CAM_DUAL_CAM0_H264         "/tmp/cam0.h264"
#define CAM_DUAL_CAM1_H264         "/tmp/cam1.h264"

static inline CVI_BOOL cam_test_phase_needs_vpss(int phase)
{
	return phase == 3 || phase == 4 || phase == 5 || phase == 7 || phase == 8;
}

static inline cam_vb_level_e cam_test_vb_level(int phase)
{
	if (phase == 2 || phase == 6)
		return CAM_VB_LEVEL_ISP;
	if (phase == 3 || phase == 7)
		return CAM_VB_LEVEL_VPSS;
	return CAM_VB_LEVEL_VENC;
}

static inline cam_vi_bringup_opts cam_test_bringup_opts(int phase)
{
	cam_vi_bringup_opts opts;

	opts.enable_dual_vpss = cam_test_phase_needs_vpss(phase) ? CVI_TRUE : CVI_FALSE;
	opts.vb_level = cam_test_vb_level(phase);
	return opts;
}

static inline CVI_BOOL cam_test_should_fast_exit(int phase, CVI_BOOL dual)
{
	if (!dual)
		return CVI_FALSE;
	return phase == 2 || phase == 4 || phase == 6 || phase == 8;
}

#endif /* CAM_TEST_CONFIG_H */
