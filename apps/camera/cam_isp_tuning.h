/*
 * cam_isp_tuning.h — 双摄 ISP PQ 调参与 VI 平台初始化
 */
#ifndef CAM_ISP_TUNING_H
#define CAM_ISP_TUNING_H

#include "sample_comm.h"

CVI_S32 cam_isp_load_pq_bin(enum CVI_BIN_SECTION_ID isp_id, const char *path);
CVI_S32 cam_isp_dual_plat_vi_init(SAMPLE_VI_CONFIG_S *pstViConfig);

#endif /* CAM_ISP_TUNING_H */
