/*
 * cam_rtsp_stream.c — RTSP 会话管理与 H.264 实时推流
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "cvi_venc.h"
#include "cam_app_context.h"
#include "cam_pipeline_config.h"
#include "cam_rtsp_stream.h"

CVI_S32 cam_rtsp_start_server(void)
{
	CVI_RTSP_CONFIG config;
	CVI_RTSP_SESSION_ATTR attr;

	memset(&config, 0, sizeof(config));
	config.port = g_cam_rtsp_port;
	config.timeout = 60;
	config.maxConnNum = 8;

	if (CVI_RTSP_Create(&g_cam_rtsp_ctx, &config) != 0) {
		printf("my_cam_test: CVI_RTSP_Create failed\n");
		return CVI_FAILURE;
	}

	memset(&attr, 0, sizeof(attr));
	attr.video.codec = RTSP_VIDEO_H264;
	attr.video.bitrate = g_cam_venc_ic.bitrate;
	strncpy(attr.name, g_cam_rtsp_url, sizeof(attr.name) - 1);

	if (CVI_RTSP_CreateSession(g_cam_rtsp_ctx, &attr, &g_cam_rtsp_session) != 0) {
		printf("my_cam_test: CVI_RTSP_CreateSession failed\n");
		CVI_RTSP_Destroy(&g_cam_rtsp_ctx);
		return CVI_FAILURE;
	}

	if (CVI_RTSP_Start(g_cam_rtsp_ctx) != 0) {
		printf("my_cam_test: CVI_RTSP_Start failed\n");
		CVI_RTSP_DestroySession(g_cam_rtsp_ctx, g_cam_rtsp_session);
		CVI_RTSP_Destroy(&g_cam_rtsp_ctx);
		return CVI_FAILURE;
	}

	g_cam_rtsp_up = CVI_TRUE;
	printf("my_cam_test: RTSP ready rtsp://<board>:%d/%s\n",
	       g_cam_rtsp_port, g_cam_rtsp_url);
	printf("Mac: ffplay -rtsp_transport tcp rtsp://192.168.42.1:%d/%s\n",
	       g_cam_rtsp_port, g_cam_rtsp_url);
	return CVI_SUCCESS;
}

CVI_S32 cam_rtsp_stream_venc(int stream_sec)
{
	VENC_STREAM_S stStream;
	VENC_CHN_STATUS_S stStat;
	CVI_RTSP_DATA rtsp_data;
	int frames = 0;
	time_t end_at;
	CVI_S32 s32Ret;

	printf("my_cam_test: waiting %d s for AE/AWB...\n", CAM_ISP_SETTLE_SEC);
	for (int i = 0; i < CAM_ISP_SETTLE_SEC && !g_cam_stop; i++)
		sleep(1);
	if (g_cam_stop)
		return CVI_FAILURE;

	end_at = time(NULL) + stream_sec;
	printf("my_cam_test: RTSP streaming for %d s (Ctrl+C to stop early)\n",
	       stream_sec);

	while (!g_cam_stop && time(NULL) < end_at) {
		memset(&stStream, 0, sizeof(stStream));
		memset(&stStat, 0, sizeof(stStat));

		s32Ret = CVI_VENC_QueryStatus(CAM_VENC_CHN_ID, &stStat);
		if (s32Ret != CVI_SUCCESS || stStat.u32CurPacks == 0) {
			usleep(10000);
			continue;
		}

		stStream.pstPack = calloc(stStat.u32CurPacks, sizeof(VENC_PACK_S));
		if (!stStream.pstPack)
			return CVI_FAILURE;

		s32Ret = CVI_VENC_GetStream(CAM_VENC_CHN_ID, &stStream,
					    g_cam_venc_ic.getstream_timeout);
		if (s32Ret != CVI_SUCCESS) {
			free(stStream.pstPack);
			usleep(10000);
			continue;
		}

		memset(&rtsp_data, 0, sizeof(rtsp_data));
		rtsp_data.blockCnt = stStream.u32PackCount;
		for (CVI_U32 i = 0; i < stStream.u32PackCount; i++) {
			VENC_PACK_S *pack = &stStream.pstPack[i];

			rtsp_data.dataPtr[i] = pack->pu8Addr + pack->u32Offset;
			rtsp_data.dataLen[i] = pack->u32Len - pack->u32Offset;
		}

		if (CVI_RTSP_WriteFrame(g_cam_rtsp_ctx, g_cam_rtsp_session->video,
					&rtsp_data) != 0)
			printf("my_cam_test: RTSP_WriteFrame failed (frame %d)\n",
			       frames + 1);

		CVI_VENC_ReleaseStream(CAM_VENC_CHN_ID, &stStream);
		free(stStream.pstPack);
		frames++;
	}

	if (frames < CAM_RTSP_MIN_FRAMES) {
		printf("my_cam_test: RTSP too few frames (%d)\n", frames);
		return CVI_FAILURE;
	}

	printf("my_cam_test: RTSP streamed %d frames\n", frames);
	return CVI_SUCCESS;
}

void cam_rtsp_teardown(void)
{
	if (!g_cam_rtsp_up)
		return;

	CVI_RTSP_Stop(g_cam_rtsp_ctx);
	CVI_RTSP_DestroySession(g_cam_rtsp_ctx, g_cam_rtsp_session);
	CVI_RTSP_Destroy(&g_cam_rtsp_ctx);
	g_cam_rtsp_session = NULL;
	g_cam_rtsp_ctx = NULL;
	g_cam_rtsp_up = CVI_FALSE;
	printf("my_cam_test: RTSP deinit done\n");
}
