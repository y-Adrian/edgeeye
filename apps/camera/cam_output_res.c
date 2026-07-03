/*
 * cam_output_res.c — 1080p / 720p / 480p 输出档位（VPSS 下采样）
 */
#include <stdio.h>
#include <string.h>
#include <strings.h>

#include "cam_app_context.h"
#include "cam_log.h"
#include "cam_output_res.h"

static cam_output_res_e g_cam_output_res = CAM_OUTPUT_RES_1080P;

void cam_output_res_set(cam_output_res_e res)
{
	if (res >= CAM_OUTPUT_RES_1080P && res <= CAM_OUTPUT_RES_480P)
		g_cam_output_res = res;
}

cam_output_res_e cam_output_res_get(void)
{
	return g_cam_output_res;
}

static int str_eq(const char *a, const char *b)
{
	return strcasecmp(a, b) == 0;
}

CVI_S32 cam_output_res_parse(const char *str, cam_output_res_e *out)
{
	if (!str || !out)
		return CVI_FAILURE;

	if (str_eq(str, "1080p") || str_eq(str, "1080") || str_eq(str, "high") ||
	    str_eq(str, "hd"))
		*out = CAM_OUTPUT_RES_1080P;
	else if (str_eq(str, "720p") || str_eq(str, "720") || str_eq(str, "medium") ||
		 str_eq(str, "md"))
		*out = CAM_OUTPUT_RES_720P;
	else if (str_eq(str, "480p") || str_eq(str, "480") || str_eq(str, "low") ||
		 str_eq(str, "vga"))
		*out = CAM_OUTPUT_RES_480P;
	else
		return CVI_FAILURE;

	return CVI_SUCCESS;
}

const char *cam_output_res_name(cam_output_res_e res)
{
	switch (res) {
	case CAM_OUTPUT_RES_720P:
		return "720p";
	case CAM_OUTPUT_RES_480P:
		return "480p";
	case CAM_OUTPUT_RES_1080P:
	default:
		return "1080p";
	}
}

CVI_S32 cam_output_res_to_size(cam_output_res_e res, SIZE_S *pstSize)
{
	if (!pstSize)
		return CVI_FAILURE;

	switch (res) {
	case CAM_OUTPUT_RES_720P:
		pstSize->u32Width = 1280;
		pstSize->u32Height = 720;
		break;
	case CAM_OUTPUT_RES_480P:
		pstSize->u32Width = 640;
		pstSize->u32Height = 480;
		break;
	case CAM_OUTPUT_RES_1080P:
	default:
		pstSize->u32Width = 1920;
		pstSize->u32Height = 1080;
		break;
	}
	return CVI_SUCCESS;
}

PIC_SIZE_E cam_output_res_to_pic_size(cam_output_res_e res)
{
	switch (res) {
	case CAM_OUTPUT_RES_720P:
		return PIC_720P;
	case CAM_OUTPUT_RES_480P:
		return PIC_640x480;
	case CAM_OUTPUT_RES_1080P:
	default:
		return PIC_1080P;
	}
}

CVI_U32 cam_output_res_bitrate_kbps(cam_output_res_e res)
{
	switch (res) {
	case CAM_OUTPUT_RES_720P:
		return 2048;
	case CAM_OUTPUT_RES_480P:
		return 1024;
	case CAM_OUTPUT_RES_1080P:
	default:
		return 4096;
	}
}

CVI_U32 cam_output_res_max_bitrate_kbps(cam_output_res_e res)
{
	switch (res) {
	case CAM_OUTPUT_RES_720P:
		return 2560;
	case CAM_OUTPUT_RES_480P:
		return 1536;
	case CAM_OUTPUT_RES_1080P:
	default:
		return 5000;
	}
}

CVI_S32 cam_sensor_size_by_cam(int cam_idx, SIZE_S *pstSrc, PIC_SIZE_E *penPicSize)
{
	PIC_SIZE_E enPicSize;
	CVI_S32 s32Ret;

	if (cam_idx < 0 || cam_idx >= g_cam_vi_cfg.s32WorkingViNum)
		return CVI_FAILURE;

	s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
		g_cam_vi_cfg.astViInfo[cam_idx].stSnsInfo.enSnsType, &enPicSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, pstSrc);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	if (penPicSize)
		*penPicSize = enPicSize;
	return CVI_SUCCESS;
}

void cam_output_res_effective(const SIZE_S *pstSrc, SIZE_S *pstOut, PIC_SIZE_E *penPicSize)
{
	SIZE_S req;
	cam_output_res_e res = cam_output_res_get();

	cam_output_res_to_size(res, &req);

	/* 输出不超过 sensor 原生（当前两路 sensor 均为 1080p） */
	if (req.u32Width > pstSrc->u32Width || req.u32Height > pstSrc->u32Height) {
		*pstOut = *pstSrc;
		if (penPicSize)
			*penPicSize = PIC_1080P;
		return;
	}

	*pstOut = req;
	if (penPicSize)
		*penPicSize = cam_output_res_to_pic_size(res);
}
