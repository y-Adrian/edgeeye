/*
 * cam_output_res.h — RTSP 输出分辨率档位（VPSS 缩放，sensor 仍 1080p 采集）
 */
#ifndef CAM_OUTPUT_RES_H
#define CAM_OUTPUT_RES_H

#include "sample_comm.h"

typedef enum {
	CAM_OUTPUT_RES_1080P = 0,
	CAM_OUTPUT_RES_720P,
	CAM_OUTPUT_RES_480P,
} cam_output_res_e;

void cam_output_res_set(cam_output_res_e res);
cam_output_res_e cam_output_res_get(void);
CVI_S32 cam_output_res_parse(const char *str, cam_output_res_e *out);
const char *cam_output_res_name(cam_output_res_e res);

CVI_S32 cam_output_res_to_size(cam_output_res_e res, SIZE_S *pstSize);
PIC_SIZE_E cam_output_res_to_pic_size(cam_output_res_e res);
CVI_U32 cam_output_res_bitrate_kbps(cam_output_res_e res);
CVI_U32 cam_output_res_max_bitrate_kbps(cam_output_res_e res);

CVI_S32 cam_sensor_size_by_cam(int cam_idx, SIZE_S *pstSrc, PIC_SIZE_E *penPicSize);
void cam_output_res_effective(const SIZE_S *pstSrc, SIZE_S *pstOut, PIC_SIZE_E *penPicSize);

#endif /* CAM_OUTPUT_RES_H */
