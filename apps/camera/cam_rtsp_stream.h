/*
 * cam_rtsp_stream.h — RTSP 服务与 VENC 码流推送（单摄/双摄）
 */
#ifndef CAM_RTSP_STREAM_H
#define CAM_RTSP_STREAM_H

typedef struct {
	int frames[2];
	int total_frames;
} cam_rtsp_stream_stats;

CVI_S32 cam_rtsp_start_server(void);
/* stream_sec <= 0：持续推流直到 g_cam_stop */
CVI_S32 cam_rtsp_stream_venc(int stream_sec, cam_rtsp_stream_stats *stats);
void cam_rtsp_teardown(void);

#endif /* CAM_RTSP_STREAM_H */
