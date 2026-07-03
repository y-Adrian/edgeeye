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

/* phase 3/4/5/7/8 需要 VPSS（及双摄在线模式） */
static inline CVI_BOOL cam_phase_needs_vpss(int phase)
{
	return phase == 3 || phase == 4 || phase == 5 || phase == 7 || phase == 8;
}

/* 双摄成功后跳过 DestroyIsp，避免内核 mempool / SDK 告警（连跑验收用） */
static inline CVI_BOOL cam_should_fast_exit(int phase)
{
	if (!cam_is_dual())
		return CVI_FALSE;
	return phase == 2 || phase == 4 || phase == 6 || phase == 8;
}

CVI_S32 cam_pipeline_wait_isp_settle(void);

#endif /* CAM_PIPELINE_MODE_H */
