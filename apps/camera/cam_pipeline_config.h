/*
 * cam_pipeline_config.h — EdgeEye 摄像头管线常量与默认路径
 */
#ifndef CAM_PIPELINE_CONFIG_H
#define CAM_PIPELINE_CONFIG_H

#define CAM_TEST_LOG_TAG           "my_cam_test"

#define CAM_DEFAULT_HOLD_SEC       10
#define CAM_DEFAULT_PHASE          2
#define CAM_DEFAULT_YUV_PATH       "/tmp/frame.yuv"
#define CAM_DEFAULT_H264_PATH      "/tmp/frame.h264"
#define CAM_DEFAULT_RTSP_PORT      8554
#define CAM_DEFAULT_RTSP_URL       "cam0"
#define CAM_DEFAULT_STREAM_SEC     30

#define CAM_VPSS_GRP_ID            0
#define CAM_VPSS_CHN_ID            VPSS_CHN0
#define CAM_VENC_CHN_ID            0
#define CAM_FRAME_WAIT_MS          3000
#define CAM_ISP_SETTLE_SEC         2
#define CAM_VENC_SAVE_TARGET_STREAMS 10
#define CAM_VENC_SAVE_MAX_ATTEMPTS 40
#define CAM_VENC_POST_START_SEC    2
#define CAM_RTSP_MIN_FRAMES        30
#define CAM_DUAL_ISP_SETTLE_SEC    10
#define CAM_MAX_SENSORS            2

#define CAM_DUAL_CAM0_YUV          "/tmp/cam0.yuv"
#define CAM_DUAL_CAM1_YUV          "/tmp/cam1.yuv"
#define CAM_DUAL_CAM0_H264         "/tmp/cam0.h264"
#define CAM_DUAL_CAM1_H264         "/tmp/cam1.h264"

#define CAM_PQ_BIN_GC2083          "/mnt/cfg/param/cvi_sdr_bin_GC2083"
#define CAM_PQ_BIN_OV5647          "/mnt/cfg/param/cvi_sdr_bin_OV5647.bin"

#endif /* CAM_PIPELINE_CONFIG_H */
