/*
 * cam_vi_bringup.h — VI/SYS 初始化与资源回收
 */
#ifndef CAM_VI_BRINGUP_H
#define CAM_VI_BRINGUP_H

#include "sample_comm.h"

void cam_vi_prepare_dual_online_config(SAMPLE_VI_CONFIG_S *pstViConfig);
CVI_S32 cam_vi_setup_dual_media_mode(void);
CVI_S32 cam_vi_bringup_init(void);
void cam_vi_bringup_deinit(void);

#endif /* CAM_VI_BRINGUP_H */
