/*
 * cam_app_context.h — 测试程序运行时全局状态
 */
#ifndef CAM_APP_CONTEXT_H
#define CAM_APP_CONTEXT_H

#include <signal.h>

#include "sample_comm.h"
#include "rtsp.h"
#include "cam_pipeline_config.h"

extern SAMPLE_VI_CONFIG_S g_cam_vi_cfg;
extern volatile sig_atomic_t g_cam_stop;
extern int g_cam_verbose;
extern int g_cam_phase;
extern int g_cam_out_path_set;
extern char g_cam_out_path[256];
extern int g_cam_rtsp_port;
extern char g_cam_rtsp_url[128];
extern CVI_BOOL g_cam_dual_media_mode;
extern CVI_BOOL g_cam_vpss_up;
extern int g_cam_vpss_grp_mask;
extern CVI_BOOL g_cam_venc_up;
extern int g_cam_venc_mask;
extern int g_cam_venc_stream_timeout[CAM_MAX_SENSORS];
extern chnInputCfg g_cam_venc_ic;
extern CVI_BOOL g_cam_rtsp_up;
extern CVI_RTSP_CTX *g_cam_rtsp_ctx;
extern CVI_RTSP_SESSION *g_cam_rtsp_session;

#endif /* CAM_APP_CONTEXT_H */
