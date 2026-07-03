/*
 * cam_test_phases.c — 各阶段管线编排（VI → VPSS → VENC → RTSP）
 */
#include <stdio.h>
#include <unistd.h>

#include "cam_app_context.h"
#include "cam_pipeline_config.h"
#include "cam_rtsp_stream.h"
#include "cam_test_phases.h"
#include "cam_venc_encode.h"
#include "cam_vpss_capture.h"

CVI_S32 cam_test_phase6_validate(void)
{
	if (g_cam_vi_cfg.s32WorkingViNum < 2) {
		printf("my_cam_test: phase 6 needs dev_num=2 in sensor_cfg.ini (working=%d)\n",
		       g_cam_vi_cfg.s32WorkingViNum);
		return CVI_FAILURE;
	}

	printf("my_cam_test: dual VI/ISP OK (%d sensors active)\n",
	       g_cam_vi_cfg.s32WorkingViNum);
	return CVI_SUCCESS;
}

CVI_S32 cam_test_phase3_run(void)
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

CVI_S32 cam_test_phase4_run(void)
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

CVI_S32 cam_test_phase5_run(int stream_sec)
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

CVI_S32 cam_test_phase7_run(void)
{
	static const char *paths[CAM_MAX_SENSORS] = { CAM_DUAL_CAM0_YUV, CAM_DUAL_CAM1_YUV };
	CVI_S32 s32Ret;
	int cam;

	s32Ret = cam_test_phase6_validate();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_init_dual(1);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	printf("my_cam_test: waiting %d s for dual AE/AWB...\n", CAM_DUAL_ISP_SETTLE_SEC);
	for (int i = 0; i < CAM_DUAL_ISP_SETTLE_SEC && !g_cam_stop; i++)
		sleep(1);
	if (g_cam_stop)
		return CVI_FAILURE;

	for (cam = 0; cam < g_cam_vi_cfg.s32WorkingViNum; cam++) {
		s32Ret = cam_vpss_capture_grp(cam_vpss_dual_grp(cam), paths[cam], CVI_FALSE);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: cam%d capture failed %#x\n", cam, s32Ret);
			return s32Ret;
		}
	}

	printf("my_cam_test: dual VPSS capture OK\n");
	return CVI_SUCCESS;
}

CVI_S32 cam_test_phase8_run(void)
{
	static const char *paths[CAM_MAX_SENSORS] = { CAM_DUAL_CAM0_H264, CAM_DUAL_CAM1_H264 };
	PIC_SIZE_E enPicSize;
	CVI_S32 s32Ret;
	int cam;

	s32Ret = cam_test_phase6_validate();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_init_dual(0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	printf("my_cam_test: waiting %d s for dual AE/AWB (before VENC)...\n",
	       CAM_DUAL_ISP_SETTLE_SEC);
	for (int i = 0; i < CAM_DUAL_ISP_SETTLE_SEC && !g_cam_stop; i++)
		sleep(1);
	if (g_cam_stop)
		return CVI_FAILURE;

	for (cam = 0; cam < g_cam_vi_cfg.s32WorkingViNum; cam++) {
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

	for (cam = 0; cam < g_cam_vi_cfg.s32WorkingViNum; cam++) {
		s32Ret = cam_venc_capture_chn((VENC_CHN)cam, paths[cam], CVI_FALSE, CVI_TRUE);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: cam%d H264 capture failed %#x\n", cam, s32Ret);
			return s32Ret;
		}
	}

	printf("my_cam_test: dual VENC capture OK\n");
	return CVI_SUCCESS;
}
