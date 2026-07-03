/*
 * cam_test_phases.c — 分阶段验收（按 dev_num 自动单摄/双摄）
 */
#include <stdio.h>
#include <unistd.h>

#include "cam_app_context.h"
#include "cam_pipeline_config.h"
#include "cam_pipeline_mode.h"
#include "cam_rtsp_stream.h"
#include "cam_test_phases.h"
#include "cam_venc_encode.h"
#include "cam_vpss_capture.h"

CVI_S32 cam_test_phase6_validate(void)
{
	if (!cam_is_dual()) {
		printf("my_cam_test: phase 6 needs dev_num=2 in sensor_cfg.ini (dev_num=%u)\n",
		       g_cam_dev_num);
		return CVI_FAILURE;
	}

	printf("my_cam_test: dual VI/ISP OK (%d sensors active)\n", cam_sensor_count());
	return CVI_SUCCESS;
}

static CVI_S32 capture_yuv_single(void)
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

	s32Ret = cam_vpss_init_single(&stSize, 1);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_bind_single();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return cam_vpss_capture_single(g_cam_out_path);
}

static CVI_S32 capture_yuv_dual(void)
{
	static const char *paths[CAM_MAX_SENSORS] = { CAM_DUAL_CAM0_YUV, CAM_DUAL_CAM1_YUV };
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
			printf("my_cam_test: cam%d capture failed %#x\n", cam, s32Ret);
			return s32Ret;
		}
	}

	printf("my_cam_test: dual VPSS capture OK\n");
	return CVI_SUCCESS;
}

CVI_S32 cam_test_capture_yuv_run(void)
{
	if (cam_is_dual())
		return capture_yuv_dual();
	return capture_yuv_single();
}

static CVI_S32 capture_h264_single(void)
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

	s32Ret = cam_vpss_init_single(&stSize, 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_bind_single();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_venc_init_single(enPicSize, 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return cam_venc_capture_single(g_cam_out_path);
}

static CVI_S32 capture_h264_dual(void)
{
	static const char *paths[CAM_MAX_SENSORS] = { CAM_DUAL_CAM0_H264, CAM_DUAL_CAM1_H264 };
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

	printf("my_cam_test: waiting %d s for VENC IDR...\n", CAM_VENC_POST_START_SEC);
	for (int i = 0; i < CAM_VENC_POST_START_SEC && !g_cam_stop; i++)
		sleep(1);
	if (g_cam_stop)
		return CVI_FAILURE;

	for (cam = 0; cam < cam_sensor_count(); cam++) {
		s32Ret = cam_venc_capture_chn((VENC_CHN)cam, paths[cam], CVI_FALSE, CVI_TRUE);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: cam%d H264 capture failed %#x\n", cam, s32Ret);
			return s32Ret;
		}
	}

	printf("my_cam_test: dual VENC capture OK\n");
	return CVI_SUCCESS;
}

CVI_S32 cam_test_capture_h264_run(void)
{
	if (cam_is_dual())
		return capture_h264_dual();
	return capture_h264_single();
}

static CVI_S32 rtsp_single(int stream_sec)
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

	s32Ret = cam_vpss_init_single(&stSize, 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_bind_single();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_venc_init_single(enPicSize, 1);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_rtsp_start_server();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return cam_rtsp_stream_venc(stream_sec);
}

static CVI_S32 rtsp_dual(int stream_sec)
{
	PIC_SIZE_E enPicSize;
	CVI_S32 s32Ret;
	int cam;

	s32Ret = cam_vpss_init_dual(0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	for (cam = 0; cam < cam_sensor_count(); cam++) {
		s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
			g_cam_vi_cfg.astViInfo[cam].stSnsInfo.enSnsType, &enPicSize);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;

		s32Ret = cam_venc_init_chn((VENC_CHN)cam, enPicSize, cam_vpss_dual_grp(cam), 1);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;
	}

	s32Ret = cam_rtsp_start_server();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return cam_rtsp_stream_venc(stream_sec);
}

CVI_S32 cam_test_rtsp_run(int stream_sec)
{
	if (cam_is_dual())
		return rtsp_dual(stream_sec);
	return rtsp_single(stream_sec);
}

/* 兼容旧脚本：phase 3/7、4/8 调用同一实现 */
CVI_S32 cam_test_phase3_run(void)
{
	return cam_test_capture_yuv_run();
}

CVI_S32 cam_test_phase4_run(void)
{
	return cam_test_capture_h264_run();
}

CVI_S32 cam_test_phase5_run(int stream_sec)
{
	return cam_test_rtsp_run(stream_sec);
}

CVI_S32 cam_test_phase7_run(void)
{
	return cam_test_capture_yuv_run();
}

CVI_S32 cam_test_phase8_run(void)
{
	return cam_test_capture_h264_run();
}
