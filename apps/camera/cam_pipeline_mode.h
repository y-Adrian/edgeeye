/*
 * cam_pipeline_mode.h — 按 sensor_cfg.ini dev_num 选择单摄/双摄管线
 */
#ifndef CAM_PIPELINE_MODE_H
#define CAM_PIPELINE_MODE_H

#include "sample_comm.h"

#include "cam_app_context.h"

extern CVI_U32 g_cam_dev_num;

static inline CVI_BOOL cam_is_dual(void)
{
	return g_cam_dev_num >= 2;
}

static inline int cam_sensor_count(void)
{
	return g_cam_vi_cfg.s32WorkingViNum > 0 ? g_cam_vi_cfg.s32WorkingViNum : 1;
}

CVI_S32 cam_pipeline_wait_isp_settle(void);

#endif /* CAM_PIPELINE_MODE_H */
