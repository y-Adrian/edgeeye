/*
 * cam_pipeline_mode.c — 单摄/双摄共用等待与模式状态
 */
#include <stdio.h>
#include <unistd.h>

#include "cam_app_context.h"
#include "cam_log.h"
#include "cam_pipeline_config.h"
#include "cam_pipeline_mode.h"

CVI_U32 g_cam_dev_num;

CVI_S32 cam_pipeline_wait_isp_settle(void)
{
	int sec = cam_is_dual() ? CAM_DUAL_ISP_SETTLE_SEC : CAM_ISP_SETTLE_SEC;

	CAM_LOG("waiting %d s for AE/AWB...\n", sec);
	for (int i = 0; i < sec && !g_cam_stop; i++)
		sleep(1);
	return g_cam_stop ? CVI_FAILURE : CVI_SUCCESS;
}
