/*
 * cam_stream_run.c — VPSS/VENC/RTSP 产品推流
 */
#include <stdio.h>

#include "cam_app_context.h"
#include "cam_log.h"
#include "cam_output_res.h"
#include "cam_pipeline_mode.h"
#include "cam_rtsp_stream.h"
#include "cam_stream_run.h"
#include "cam_venc_encode.h"
#include "cam_vpss_capture.h"

static CVI_S32 rtsp_setup_single(void)
{
	SIZE_S stSrc, stOut;
	PIC_SIZE_E enOutPic;
	CVI_S32 s32Ret;

	s32Ret = cam_sensor_size_by_cam(0, &stSrc, NULL);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	cam_output_res_effective(&stSrc, &stOut, &enOutPic);

	/*
	 * AI direct 需要 ch0 depth=1，GetChnFrame 才能与绑定到 VENC 的
	 * 同一输出并行取得一帧；未启用时保持 depth=0，避免额外占用 VB。
	 */
	s32Ret = cam_vpss_init_single(&stSrc, &stOut, g_cam_ai_direct ? 1 : 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = cam_vpss_bind_single();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return cam_venc_init_single(enOutPic, 1);
}

static CVI_S32 rtsp_setup_dual(void)
{
	PIC_SIZE_E enOutPic;
	SIZE_S stSrc, stOut;
	CVI_S32 s32Ret;
	int cam;

	s32Ret = cam_vpss_init_dual(0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	for (cam = 0; cam < cam_sensor_count(); cam++) {
		s32Ret = cam_sensor_size_by_cam(cam, &stSrc, NULL);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;

		cam_output_res_effective(&stSrc, &stOut, &enOutPic);

		s32Ret = cam_venc_init_chn((VENC_CHN)cam, enOutPic, cam_vpss_dual_grp(cam), 1);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;
	}

	return CVI_SUCCESS;
}

CVI_S32 cam_stream_rtsp_setup(void)
{
	CVI_S32 s32Ret;

	CAM_LOG("output resolution: %s\n", cam_output_res_name(cam_output_res_get()));

	if (cam_is_dual())
		s32Ret = rtsp_setup_dual();
	else
		s32Ret = rtsp_setup_single();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return cam_rtsp_start_server();
}

CVI_S32 cam_stream_rtsp_run(int stream_sec, cam_rtsp_stream_stats *stats)
{
	return cam_rtsp_stream_venc(stream_sec, stats);
}
