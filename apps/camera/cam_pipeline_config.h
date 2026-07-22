/*
 * cam_pipeline_config.h — EdgeEye 摄像头管线常量（产品库）
 */
#ifndef CAM_PIPELINE_CONFIG_H
#define CAM_PIPELINE_CONFIG_H

#define CAM_VPSS_GRP_ID            0
#define CAM_VPSS_CHN_ID            VPSS_CHN0
#define CAM_VPSS_AI_CHN_ID         VPSS_CHN1
#define CAM_AI_FRAME_WIDTH         448
#define CAM_AI_FRAME_HEIGHT        448
#define CAM_VENC_CHN_ID            0
#define CAM_FRAME_WAIT_MS          3000
#define CAM_ISP_SETTLE_SEC         2
#define CAM_VENC_POST_START_SEC    2
#define CAM_DUAL_ISP_SETTLE_SEC    10
#define CAM_MAX_SENSORS            2

#define CAM_DUAL_RTSP_URL0         "cam0"
#define CAM_DUAL_RTSP_URL1         "cam1"

#define CAM_PQ_BIN_GC2083          "/mnt/cfg/param/cvi_sdr_bin_GC2083"
#define CAM_PQ_BIN_OV5647          "/mnt/cfg/param/cvi_sdr_bin_OV5647.bin"

#endif /* CAM_PIPELINE_CONFIG_H */
