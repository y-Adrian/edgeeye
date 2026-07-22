/*
 * cam_app_context.c — 管线运行时全局状态定义
 */
#include "cam_app_context.h"

SAMPLE_VI_CONFIG_S g_cam_vi_cfg;
volatile sig_atomic_t g_cam_stop;
int g_cam_verbose;
int g_cam_rtsp_port = 8554;
char g_cam_rtsp_url[128] = CAM_DUAL_RTSP_URL0;
CVI_BOOL g_cam_ai_direct;
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
