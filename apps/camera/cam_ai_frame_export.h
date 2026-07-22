/*
 * cam_ai_frame_export.h — 从 edgeeye_cam 的 VPSS 通道按请求导出 AI 帧
 */
#ifndef CAM_AI_FRAME_EXPORT_H
#define CAM_AI_FRAME_EXPORT_H

#include "sample_comm.h"

#define CAM_AI_FRAME_REQUEST_PATH "/tmp/edgeeye_ai_frame.request"
#define CAM_AI_FRAME_RAW_PATH     "/tmp/edgeeye_ai_frame.nv12"
#define CAM_AI_FRAME_META_PATH    "/tmp/edgeeye_ai_frame.meta"

CVI_S32 cam_ai_frame_export_start(void);
void cam_ai_frame_export_stop(void);

#endif /* CAM_AI_FRAME_EXPORT_H */
