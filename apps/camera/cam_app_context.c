/*
 * cam_app_context.c — 测试程序运行时全局状态定义
 */
#include "cam_app_context.h"

SAMPLE_VI_CONFIG_S g_cam_vi_cfg;
volatile sig_atomic_t g_cam_stop;
int g_cam_verbose;
int g_cam_phase = CAM_DEFAULT_PHASE;
int g_cam_out_path_set;
char g_cam_out_path[256] = CAM_DEFAULT_YUV_PATH;
int g_cam_rtsp_port = CAM_DEFAULT_RTSP_PORT;
char g_cam_rtsp_url[128] = CAM_DEFAULT_RTSP_URL;
CVI_BOOL g_cam_dual_media_mode;
CVI_BOOL g_cam_vpss_up;
int g_cam_vpss_grp_mask;
CVI_BOOL g_cam_venc_up;
int g_cam_venc_mask;
int g_cam_venc_stream_timeout[CAM_MAX_SENSORS];
chnInputCfg g_cam_venc_ic;
CVI_BOOL g_cam_rtsp_up;
CVI_RTSP_CTX *g_cam_rtsp_ctx;
CVI_RTSP_SESSION *g_cam_rtsp_sessions[CAM_MAX_SENSORS];
int g_cam_rtsp_session_mask;
