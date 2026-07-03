/*
 * cam_vpss_capture.h — VPSS 组初始化、VI 绑定与 NV12 抓帧
 */
#ifndef CAM_VPSS_CAPTURE_H
#define CAM_VPSS_CAPTURE_H

#include "sample_comm.h"

/* pstOutSize 为 NULL 时与 pstSrcSize 相同（不缩放） */
CVI_S32 cam_vpss_init_grp(VPSS_GRP vpss_grp, const SIZE_S *pstSrcSize,
			  const SIZE_S *pstOutSize, CVI_U32 depth, CVI_U8 vpss_dev);
CVI_S32 cam_vpss_init_single(const SIZE_S *pstSrcSize, const SIZE_S *pstOutSize,
			     CVI_U32 depth);
CVI_S32 cam_vpss_bind_cam(int cam_idx);
CVI_S32 cam_vpss_bind_single(void);
CVI_S32 cam_vpss_capture_grp(VPSS_GRP vpss_grp, const char *path, CVI_BOOL do_settle);
CVI_S32 cam_vpss_capture_single(const char *path);
VPSS_GRP cam_vpss_dual_grp(int cam);
CVI_S32 cam_vpss_init_dual(CVI_U32 depth);
void cam_vpss_teardown(void);

#endif /* CAM_VPSS_CAPTURE_H */
