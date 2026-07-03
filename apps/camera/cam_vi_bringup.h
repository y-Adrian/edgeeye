/*
 * cam_vi_bringup.h — VI/SYS 初始化与资源回收
 */
#ifndef CAM_VI_BRINGUP_H
#define CAM_VI_BRINGUP_H

#include "sample_comm.h"

typedef enum {
	CAM_VB_LEVEL_ISP = 0,
	CAM_VB_LEVEL_VPSS,
	CAM_VB_LEVEL_VENC,
} cam_vb_level_e;

typedef struct {
	CVI_BOOL enable_dual_vpss;
	cam_vb_level_e vb_level;
} cam_vi_bringup_opts;

void cam_vi_prepare_dual_online_config(SAMPLE_VI_CONFIG_S *pstViConfig);
CVI_S32 cam_vi_setup_dual_media_mode(void);
CVI_S32 cam_vi_bringup_init(const cam_vi_bringup_opts *opts);
void cam_vi_bringup_deinit(void);

#endif /* CAM_VI_BRINGUP_H */
