/*
 * cam_test_phases.c — my_cam_test 分阶段验收（按 dev_num 自动单摄/双摄）
 */
#include <stdio.h>
#include <unistd.h>

#include "cam_app_context.h"
#include "cam_pipeline_config.h"
#include "cam_pipeline_mode.h"
#include "cam_rtsp_stream.h"
#include "cam_stream_run.h"
#include "cam_test_config.h"
#include "cam_test_phases.h"
#include "cam_venc_encode.h"
#include "cam_vpss_capture.h"

static const cam_venc_save_opts g_cam_test_venc_save_opts = {
	.target_streams = CAM_VENC_SAVE_TARGET_STREAMS,
	.max_attempts = CAM_VENC_SAVE_MAX_ATTEMPTS,
	.min_bytes = CAM_VENC_SAVE_MIN_BYTES,
};

CVI_S32 cam_test_phase6_validate(void)
{
	if (!cam_is_dual()) {
		printf("%s: phase 6 needs dev_num=2 in sensor_cfg.ini (dev_num=%u)\n",
		       CAM_TEST_LOG_TAG, g_cam_dev_num);
		return CVI_FAILURE;
	}

	printf("%s: dual VI/ISP OK (%d sensors active)\n",
	       CAM_TEST_LOG_TAG, cam_sensor_count());
	return CVI_SUCCESS;
}

static CVI_S32 capture_yuv_single(const char *path)
{
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	CVI_S32 s32Ret;

	s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
		g_cam_vi_cfg.astViInfo[0].stSnsInfo.enSnsType, &enPicSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, &stSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_init_single(&stSize, NULL, 1);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_bind_single();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return cam_vpss_capture_single(path);
}

static CVI_S32 capture_yuv_dual(void)
{
	static const char *paths[2] = { CAM_DUAL_CAM0_YUV, CAM_DUAL_CAM1_YUV };
	CVI_S32 s32Ret;
	int cam;

	s32Ret = cam_vpss_init_dual(1);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	if (cam_pipeline_wait_isp_settle() != CVI_SUCCESS)
		return CVI_FAILURE;

	for (cam = 0; cam < cam_sensor_count(); cam++) {
		s32Ret = cam_vpss_capture_grp(cam_vpss_dual_grp(cam), paths[cam], CVI_FALSE);
		if (s32Ret != CVI_SUCCESS) {
			printf("%s: cam%d capture failed %#x\n", CAM_TEST_LOG_TAG, cam, s32Ret);
			return s32Ret;
		}
	}

	printf("%s: dual VPSS capture OK\n", CAM_TEST_LOG_TAG);
	return CVI_SUCCESS;
}

CVI_S32 cam_test_capture_yuv_run(const char *single_path)
{
	if (cam_is_dual())
		return capture_yuv_dual();
	return capture_yuv_single(single_path);
}

static CVI_S32 capture_h264_single(const char *path)
{
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	CVI_S32 s32Ret;

	s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
		g_cam_vi_cfg.astViInfo[0].stSnsInfo.enSnsType, &enPicSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, &stSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_init_single(&stSize, NULL, 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_bind_single();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_venc_init_single(enPicSize, 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return cam_venc_capture_single(path, &g_cam_test_venc_save_opts);
}

static CVI_S32 capture_h264_dual(void)
{
	static const char *paths[2] = { CAM_DUAL_CAM0_H264, CAM_DUAL_CAM1_H264 };
	PIC_SIZE_E enPicSize;
	CVI_S32 s32Ret;
	int cam;

	s32Ret = cam_vpss_init_dual(0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	if (cam_pipeline_wait_isp_settle() != CVI_SUCCESS)
		return CVI_FAILURE;

	for (cam = 0; cam < cam_sensor_count(); cam++) {
		s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
			g_cam_vi_cfg.astViInfo[cam].stSnsInfo.enSnsType, &enPicSize);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;

		s32Ret = cam_venc_init_chn((VENC_CHN)cam, enPicSize, cam_vpss_dual_grp(cam), 0);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;
	}

	printf("%s: waiting %d s for VENC IDR...\n",
	       CAM_TEST_LOG_TAG, CAM_VENC_POST_START_SEC);
	for (int i = 0; i < CAM_VENC_POST_START_SEC && !g_cam_stop; i++)
		sleep(1);
	if (g_cam_stop)
		return CVI_FAILURE;

	for (cam = 0; cam < cam_sensor_count(); cam++) {
		s32Ret = cam_venc_capture_chn((VENC_CHN)cam, paths[cam], CVI_FALSE, CVI_TRUE,
					      &g_cam_test_venc_save_opts);
		if (s32Ret != CVI_SUCCESS) {
			printf("%s: cam%d H264 capture failed %#x\n", CAM_TEST_LOG_TAG, cam, s32Ret);
			return s32Ret;
		}
	}

	printf("%s: dual VENC capture OK\n", CAM_TEST_LOG_TAG);
	return CVI_SUCCESS;
}

CVI_S32 cam_test_capture_h264_run(const char *single_path)
{
	if (cam_is_dual())
		return capture_h264_dual();
	return capture_h264_single(single_path);
}

CVI_S32 cam_test_rtsp_run(int stream_sec)
{
	cam_rtsp_stream_stats stats;
	CVI_S32 s32Ret;

	s32Ret = cam_stream_rtsp_setup();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_stream_rtsp_run(stream_sec, &stats);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	if (stats.total_frames < CAM_RTSP_MIN_FRAMES) {
		printf("%s: RTSP too few frames (%d)\n", CAM_TEST_LOG_TAG, stats.total_frames);
		return CVI_FAILURE;
	}
	return CVI_SUCCESS;
}

CVI_S32 cam_test_phase3_run(const char *single_path)
{
	return cam_test_capture_yuv_run(single_path);
}

CVI_S32 cam_test_phase4_run(const char *single_path)
{
	return cam_test_capture_h264_run(single_path);
}

CVI_S32 cam_test_phase5_run(int stream_sec)
{
	return cam_test_rtsp_run(stream_sec);
}

CVI_S32 cam_test_phase7_run(void)
{
	return cam_test_capture_yuv_run(CAM_DEFAULT_YUV_PATH);
}

CVI_S32 cam_test_phase8_run(void)
{
	return cam_test_capture_h264_run(CAM_DEFAULT_H264_PATH);
}
