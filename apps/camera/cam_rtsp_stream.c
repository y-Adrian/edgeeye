/*
 * cam_rtsp_stream.c — RTSP 会话管理（单摄 1 路 / 双摄 cam0+cam1）
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "cvi_venc.h"
#include "cam_app_context.h"
#include "cam_log.h"
#include "cam_pipeline_config.h"
#include "cam_pipeline_mode.h"
#include "cam_rtsp_stream.h"

static const char *rtsp_url_for_cam(int cam)
{
	if (!cam_is_dual())
		return g_cam_rtsp_url;
	return cam == 0 ? CAM_DUAL_RTSP_URL0 : CAM_DUAL_RTSP_URL1;
}

static CVI_S32 rtsp_create_session(VENC_CHN venc_chn, const char *url,
				   CVI_RTSP_SESSION **out_sess)
{
	CVI_RTSP_SESSION_ATTR attr;

	memset(&attr, 0, sizeof(attr));
	attr.video.codec = RTSP_VIDEO_H264;
	attr.video.bitrate = g_cam_venc_ic.bitrate;
	strncpy(attr.name, url, sizeof(attr.name) - 1);

	if (CVI_RTSP_CreateSession(g_cam_rtsp_ctx, &attr, out_sess) != 0) {
		CAM_LOG("CVI_RTSP_CreateSession(%s) failed\n", url);
		return CVI_FAILURE;
	}

	CAM_LOG("RTSP session chn%d -> rtsp://<board>:%d/%s\n",
	       venc_chn, g_cam_rtsp_port, url);
	return CVI_SUCCESS;
}

CVI_S32 cam_rtsp_start_server(void)
{
	CVI_RTSP_CONFIG config;
	CVI_S32 s32Ret;
	int cam, n;

	memset(&config, 0, sizeof(config));
	config.port = g_cam_rtsp_port;
	config.timeout = 60;
	config.maxConnNum = 8;

	if (CVI_RTSP_Create(&g_cam_rtsp_ctx, &config) != 0) {
		CAM_LOG("CVI_RTSP_Create failed\n");
		return CVI_FAILURE;
	}

	n = cam_is_dual() ? cam_sensor_count() : 1;
	for (cam = 0; cam < n; cam++) {
		s32Ret = rtsp_create_session((VENC_CHN)cam, rtsp_url_for_cam(cam),
					     &g_cam_rtsp_sessions[cam]);
		if (s32Ret != CVI_SUCCESS) {
			cam_rtsp_teardown();
			return s32Ret;
		}
		g_cam_rtsp_session_mask |= (1 << cam);
	}

	if (CVI_RTSP_Start(g_cam_rtsp_ctx) != 0) {
		CAM_LOG("CVI_RTSP_Start failed\n");
		cam_rtsp_teardown();
		return CVI_FAILURE;
	}

	g_cam_rtsp_up = CVI_TRUE;
	printf("Mac preview:\n");
	for (cam = 0; cam < n; cam++)
		printf("  ffplay -rtsp_transport tcp rtsp://192.168.42.1:%d/%s\n",
		       g_cam_rtsp_port, rtsp_url_for_cam(cam));
	return CVI_SUCCESS;
}

static CVI_S32 rtsp_push_venc_chn(VENC_CHN venc_chn, int *frames_out)
{
	VENC_STREAM_S stStream;
	VENC_CHN_STATUS_S stStat;
	CVI_RTSP_DATA rtsp_data;
	CVI_S32 s32Ret;
	int timeout_ms = g_cam_venc_stream_timeout[venc_chn];

	if (timeout_ms <= 0)
		timeout_ms = CAM_FRAME_WAIT_MS;

	memset(&stStream, 0, sizeof(stStream));
	memset(&stStat, 0, sizeof(stStat));

	s32Ret = CVI_VENC_QueryStatus(venc_chn, &stStat);
	if (s32Ret != CVI_SUCCESS || stStat.u32CurPacks == 0)
		return CVI_FAILURE;

	stStream.pstPack = calloc(stStat.u32CurPacks, sizeof(VENC_PACK_S));
	if (!stStream.pstPack)
		return CVI_FAILURE;

	s32Ret = CVI_VENC_GetStream(venc_chn, &stStream, timeout_ms);
	if (s32Ret != CVI_SUCCESS) {
		free(stStream.pstPack);
		return CVI_FAILURE;
	}

	memset(&rtsp_data, 0, sizeof(rtsp_data));
	rtsp_data.blockCnt = stStream.u32PackCount;
	for (CVI_U32 i = 0; i < stStream.u32PackCount; i++) {
		VENC_PACK_S *pack = &stStream.pstPack[i];

		rtsp_data.dataPtr[i] = pack->pu8Addr + pack->u32Offset;
		rtsp_data.dataLen[i] = pack->u32Len - pack->u32Offset;
	}

	if (g_cam_rtsp_sessions[venc_chn] &&
	    CVI_RTSP_WriteFrame(g_cam_rtsp_ctx, g_cam_rtsp_sessions[venc_chn]->video,
				&rtsp_data) != 0)
		CAM_LOG("RTSP_WriteFrame chn%d failed\n", venc_chn);

	CVI_VENC_ReleaseStream(venc_chn, &stStream);
	free(stStream.pstPack);
	if (frames_out)
		(*frames_out)++;
	return CVI_SUCCESS;
}

CVI_S32 cam_rtsp_stream_venc(int stream_sec, cam_rtsp_stream_stats *stats)
{
	time_t end_at = 0;
	int frames[CAM_MAX_SENSORS] = {0};
	int cam, total_frames = 0;

	if (stats)
		memset(stats, 0, sizeof(*stats));

	if (cam_pipeline_wait_isp_settle() != CVI_SUCCESS)
		return CVI_FAILURE;

	if (stream_sec > 0) {
		end_at = time(NULL) + stream_sec;
		CAM_LOG("RTSP streaming %d s (%s)\n", stream_sec,
			cam_is_dual() ? "dual cam0+cam1" : "single");
	} else {
		end_at = 0;
		CAM_LOG("RTSP streaming until stop (%s)\n",
			cam_is_dual() ? "dual cam0+cam1" : "single");
	}

	while (!g_cam_stop && (stream_sec <= 0 || time(NULL) < end_at)) {
		for (cam = 0; cam < cam_sensor_count(); cam++) {
			if (!(g_cam_venc_mask & (1 << cam)))
				continue;
			rtsp_push_venc_chn((VENC_CHN)cam, &frames[cam]);
		}
		usleep(5000);
	}

	for (cam = 0; cam < cam_sensor_count(); cam++)
		total_frames += frames[cam];

	if (stats) {
		stats->total_frames = total_frames;
		stats->frames[0] = frames[0];
		stats->frames[1] = frames[1];
	}

	CAM_LOG("RTSP streamed %d frames", total_frames);
	if (cam_is_dual())
		printf(" (cam0=%d cam1=%d)", frames[0], frames[1]);
	printf("\n");
	return CVI_SUCCESS;
}

void cam_rtsp_teardown(void)
{
	int cam;

	if (!g_cam_rtsp_up)
		return;

	CVI_RTSP_Stop(g_cam_rtsp_ctx);
	for (cam = CAM_MAX_SENSORS - 1; cam >= 0; cam--) {
		if (!(g_cam_rtsp_session_mask & (1 << cam)))
			continue;
		CVI_RTSP_DestroySession(g_cam_rtsp_ctx, g_cam_rtsp_sessions[cam]);
		g_cam_rtsp_sessions[cam] = NULL;
	}
	CVI_RTSP_Destroy(&g_cam_rtsp_ctx);
	g_cam_rtsp_ctx = NULL;
	g_cam_rtsp_session_mask = 0;
	g_cam_rtsp_up = CVI_FALSE;
	CAM_LOG("RTSP deinit done\n");
}
