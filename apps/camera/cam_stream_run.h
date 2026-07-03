/*
 * cam_stream_run.h — 产品 RTSP 推流管线（VI 已 init 后调用）
 */
#ifndef CAM_STREAM_RUN_H
#define CAM_STREAM_RUN_H

#include "cam_rtsp_stream.h"

CVI_S32 cam_stream_rtsp_setup(void);
/* stream_sec <= 0：一直推流直到 g_cam_stop */
CVI_S32 cam_stream_rtsp_run(int stream_sec, cam_rtsp_stream_stats *stats);

#endif /* CAM_STREAM_RUN_H */
