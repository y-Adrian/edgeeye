/*
 * cam_rtsp_stream.h — RTSP 服务与 VENC 码流推送
 */
#ifndef CAM_RTSP_STREAM_H
#define CAM_RTSP_STREAM_H

CVI_S32 cam_rtsp_start_server(void);
CVI_S32 cam_rtsp_stream_venc(int stream_sec);
void cam_rtsp_teardown(void);

#endif /* CAM_RTSP_STREAM_H */
