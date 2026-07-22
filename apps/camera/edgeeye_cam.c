/*
 * edgeeye_cam.c — EdgeEye 产品 RTSP 直播（单摄/双摄）
 *
 * 用法：
 *   edgeeye_cam --single gc2083
 *   edgeeye_cam --single ov5647
 *   edgeeye_cam --dual
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cam_ai_frame_export.h"
#include "cam_app_context.h"
#include "cam_log.h"
#include "cam_pipeline_mode.h"
#include "cam_output_res.h"
#include "cam_sensor_setup.h"
#include "cam_stream_run.h"
#include "cam_vi_bringup.h"

static volatile sig_atomic_t g_run_stop;

static void handle_signal(int signo)
{
	(void)signo;
	g_run_stop = 1;
	g_cam_stop = 1;
}

static void usage(const char *prog)
{
	printf("Usage: %s --single <gc2083|ov5647> | --dual [options]\n", prog);
	printf("  --single gc2083   J1 Milk-V 模组\n");
	printf("  --single ov5647   J2 树莓派模组\n");
	printf("  --dual            GC2083 + OV5647 同时直播 cam0/cam1\n");
	printf("  -P, --port N      RTSP 端口 (default 8554)\n");
	printf("  -r, --res RES     输出分辨率: 1080p|720p|480p (default 1080p)\n");
	printf("  --ai-direct       开启 VPSS 按需导帧（单摄，供 AI 使用）\n");
	printf("  -v                VI/ISP/VPSS 调试日志\n");
	printf("\nMac 预览:\n");
	printf("  ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0\n");
	printf("  ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam1  # dual only\n");
}

static void print_preview_urls(int port, cam_layout_e layout, cam_sensor_id_e sensor)
{
	const char *mode;

	if (layout == CAM_LAYOUT_DUAL)
		mode = "dual";
	else if (sensor == CAM_SENSOR_OV5647)
		mode = "ov5647";
	else
		mode = "gc2083";

	printf("\n=== EdgeEye RTSP ready (%s) ===\n", cam_output_res_name(cam_output_res_get()));
	printf("  rtsp://192.168.42.1:%d/cam0\n", port);
	if (layout == CAM_LAYOUT_DUAL)
		printf("  rtsp://192.168.42.1:%d/cam1\n", port);
	printf("Mac: ./scripts/preview_my_cam_rtsp_mac.sh --mode %s --start-board\n", mode);
	fflush(stdout);
}

int main(int argc, char **argv)
{
	cam_layout_e layout = CAM_LAYOUT_SINGLE;
	cam_sensor_id_e sensor = CAM_SENSOR_GC2083;
	cam_vi_bringup_opts bringup = {
		.enable_dual_vpss = CVI_TRUE,
		.vb_level = CAM_VB_LEVEL_VENC,
	};
	CVI_S32 s32Ret;
	int opt;
	CVI_BOOL have_mode = CVI_FALSE;
	cam_output_res_e res = CAM_OUTPUT_RES_1080P;

	for (opt = 1; opt < argc; opt++) {
		if (strcmp(argv[opt], "-h") == 0 || strcmp(argv[opt], "--help") == 0) {
			usage(argv[0]);
			return 0;
		}
		if (strcmp(argv[opt], "--single") == 0 && opt + 1 < argc) {
			layout = CAM_LAYOUT_SINGLE;
			have_mode = CVI_TRUE;
			if (strcmp(argv[++opt], "ov5647") == 0 ||
			    strcmp(argv[opt], "OV5647") == 0 ||
			    strcmp(argv[opt], "j2") == 0)
				sensor = CAM_SENSOR_OV5647;
			else
				sensor = CAM_SENSOR_GC2083;
			continue;
		}
		if (strcmp(argv[opt], "--dual") == 0) {
			layout = CAM_LAYOUT_DUAL;
			have_mode = CVI_TRUE;
			continue;
		}
		if ((strcmp(argv[opt], "-P") == 0 || strcmp(argv[opt], "--port") == 0) &&
		    opt + 1 < argc) {
			g_cam_rtsp_port = atoi(argv[++opt]);
			continue;
		}
		if (strcmp(argv[opt], "-v") == 0) {
			g_cam_verbose = 1;
			continue;
		}
		if (strcmp(argv[opt], "--ai-direct") == 0) {
			g_cam_ai_direct = CVI_TRUE;
			continue;
		}
		if ((strcmp(argv[opt], "-r") == 0 || strcmp(argv[opt], "--res") == 0) &&
		    opt + 1 < argc) {
			if (cam_output_res_parse(argv[++opt], &res) != CVI_SUCCESS) {
				printf("edgeeye_cam: unknown resolution '%s'\n", argv[opt]);
				usage(argv[0]);
				return 1;
			}
			continue;
		}
		usage(argv[0]);
		return 1;
	}

	if (!have_mode) {
		printf("edgeeye_cam: specify --single <sensor> or --dual\n");
		usage(argv[0]);
		return 1;
	}

	if (layout == CAM_LAYOUT_SINGLE)
		bringup.enable_dual_vpss = CVI_FALSE;
	if (layout == CAM_LAYOUT_DUAL && g_cam_ai_direct) {
		printf("edgeeye_cam: --ai-direct currently supports single camera only\n");
		return 1;
	}

	cam_output_res_set(res);

	signal(SIGPIPE, SIG_IGN);
	signal(SIGINT, handle_signal);
	signal(SIGTERM, handle_signal);

	printf("=== EdgeEye camera (%s, %s) ===\n",
	       layout == CAM_LAYOUT_DUAL ? "dual" :
	       (sensor == CAM_SENSOR_OV5647 ? "single ov5647" : "single gc2083"),
	       cam_output_res_name(res));

	s32Ret = cam_sensor_setup(layout, sensor);
	if (s32Ret != CVI_SUCCESS)
		return 1;

	s32Ret = cam_vi_bringup_init(&bringup);
	if (s32Ret != CVI_SUCCESS) {
		printf("edgeeye_cam: init failed %#x\n", s32Ret);
		return 1;
	}

	s32Ret = cam_stream_rtsp_setup();
	if (s32Ret != CVI_SUCCESS) {
		printf("edgeeye_cam: RTSP setup failed %#x\n", s32Ret);
		cam_vi_bringup_deinit();
		return 1;
	}

	print_preview_urls(g_cam_rtsp_port, layout, sensor);

	if (g_cam_ai_direct) {
		/* cam_ai_frame_export_start：启动 VPSS 按需导帧线程。 */
		s32Ret = cam_ai_frame_export_start();
		if (s32Ret != CVI_SUCCESS) {
			printf("edgeeye_cam: AI direct exporter failed %#x\n", s32Ret);
			cam_vi_bringup_deinit();
			return 1;
		}
	}

	/* stream_sec <= 0：持续推流直到 Ctrl+C */
	s32Ret = cam_stream_rtsp_run(0, NULL);
	if (s32Ret != CVI_SUCCESS && !g_run_stop)
		printf("edgeeye_cam: stream ended %#x\n", s32Ret);

	/* cam_ai_frame_export_stop：归还导帧线程可能持有的 VPSS 帧。 */
	cam_ai_frame_export_stop();
	cam_vi_bringup_deinit();
	printf("edgeeye_cam: stopped\n");
	return s32Ret == CVI_SUCCESS || g_run_stop ? 0 : 1;
}
