/*
 * cam_venc_encode.h — H.264 编码通道与码流抓取
 */
#ifndef CAM_VENC_ENCODE_H
#define CAM_VENC_ENCODE_H

#include "sample_comm.h"

CVI_S32 cam_venc_init_chn(VENC_CHN venc_chn, PIC_SIZE_E enPicSize, VPSS_GRP vpss_grp,
			  int continuous);
CVI_S32 cam_venc_init_single(PIC_SIZE_E enPicSize, int continuous);
CVI_S32 cam_venc_capture_chn(VENC_CHN venc_chn, const char *path, CVI_BOOL do_settle,
			     CVI_BOOL save_from_idr);
CVI_S32 cam_venc_capture_single(const char *path);
void cam_venc_teardown(void);

#endif /* CAM_VENC_ENCODE_H */
