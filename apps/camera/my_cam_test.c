/*
 * my_cam_test.c — EdgeEye 摄像头渐进验收程序入口（phase 2～8）
 *
 * 模块划分见同目录 cam_*.c / cam_*.h。
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "cam_app_context.h"
#include "cam_pipeline_config.h"
#include "cam_test_phases.h"
#include "cam_vi_bringup.h"

static void handle_signal(int signo)
{
	(void)signo;
	g_cam_stop = 1;
}

static void usage(const char *prog)
{
	printf("Usage: %s [-p PHASE] [-s SECONDS] [-o PATH] [-P PORT] [-u URL] [-v]\n",
	       prog);
	printf("  Phase 2: init VI/ISP, hold, exit (default)\n");
	printf("  Phase 3: VI -> VPSS, capture one NV12 frame\n");
	printf("  Phase 4: VI -> VPSS -> VENC, write H.264 elementary stream\n");
	printf("  Phase 5: VI -> VPSS -> VENC -> RTSP live preview\n");
	printf("  Phase 6: dual VI/ISP init (requires dev_num=2 ini)\n");
	printf("  Phase 7: dual VI -> VPSS, capture NV12 per camera\n");
	printf("  Phase 8: dual VI -> VPSS -> VENC, write H.264 per camera\n");
	printf("  -p  2, 3, 4, 5, 6, 7, or 8 (default %d)\n", CAM_DEFAULT_PHASE);
	printf("  -o  phase 3 default %s; phase 4 default %s\n",
	       CAM_DEFAULT_YUV_PATH, CAM_DEFAULT_H264_PATH);
	printf("  -s  phase 2/6 hold seconds (default %d); phase 5 stream seconds (default %d)\n",
	       CAM_DEFAULT_HOLD_SEC, CAM_DEFAULT_STREAM_SEC);
	printf("  -P  RTSP port for phase 5 (default %d)\n", CAM_DEFAULT_RTSP_PORT);
	printf("  -u  RTSP URL path for phase 5 (default %s)\n", CAM_DEFAULT_RTSP_URL);
	printf("  -v  VI/ISP/VPSS/VENC/VB debug logs\n");
}

int main(int argc, char **argv)
{
	int hold_sec = CAM_DEFAULT_HOLD_SEC;
	int stream_sec = CAM_DEFAULT_STREAM_SEC;
	int opt;
	CVI_S32 s32Ret;

	for (opt = 1; opt < argc; opt++) {
		if (strcmp(argv[opt], "-h") == 0 || strcmp(argv[opt], "--help") == 0) {
			usage(argv[0]);
			return 0;
		}
		if (strcmp(argv[opt], "-p") == 0 && opt + 1 < argc) {
			g_cam_phase = atoi(argv[++opt]);
			if (g_cam_phase < 2 || g_cam_phase > 8) {
				printf("my_cam_test: invalid phase %d (use 2-8)\n", g_cam_phase);
				return 1;
			}
			continue;
		}
		if (strcmp(argv[opt], "-s") == 0 && opt + 1 < argc) {
			hold_sec = atoi(argv[++opt]);
			stream_sec = hold_sec;
			if (hold_sec < 1)
				hold_sec = stream_sec = 1;
			continue;
		}
		if (strcmp(argv[opt], "-o") == 0 && opt + 1 < argc) {
			strncpy(g_cam_out_path, argv[++opt], sizeof(g_cam_out_path) - 1);
			g_cam_out_path[sizeof(g_cam_out_path) - 1] = '\0';
			g_cam_out_path_set = 1;
			continue;
		}
		if (strcmp(argv[opt], "-P") == 0 && opt + 1 < argc) {
			g_cam_rtsp_port = atoi(argv[++opt]);
			if (g_cam_rtsp_port < 1 || g_cam_rtsp_port > 65535) {
				printf("my_cam_test: invalid RTSP port %d\n", g_cam_rtsp_port);
				return 1;
			}
			continue;
		}
		if (strcmp(argv[opt], "-u") == 0 && opt + 1 < argc) {
			strncpy(g_cam_rtsp_url, argv[++opt], sizeof(g_cam_rtsp_url) - 1);
			g_cam_rtsp_url[sizeof(g_cam_rtsp_url) - 1] = '\0';
			continue;
		}
		if (strcmp(argv[opt], "-v") == 0) {
			g_cam_verbose = 1;
			continue;
		}
		usage(argv[0]);
		return 1;
	}

	signal(SIGPIPE, SIG_IGN);
	signal(SIGINT, handle_signal);
	signal(SIGTERM, handle_signal);

	if (!g_cam_out_path_set) {
		if (g_cam_phase == 4)
			strncpy(g_cam_out_path, CAM_DEFAULT_H264_PATH, sizeof(g_cam_out_path) - 1);
		else if (g_cam_phase == 3)
			strncpy(g_cam_out_path, CAM_DEFAULT_YUV_PATH, sizeof(g_cam_out_path) - 1);
		g_cam_out_path[sizeof(g_cam_out_path) - 1] = '\0';
	}

	printf("=== EdgeEye my_cam_test (phase %d) ===\n", g_cam_phase);

	s32Ret = cam_vi_bringup_init();
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: FAILED init %#x\n", s32Ret);
		return 1;
	}

	if (g_cam_phase == 3) {
		s32Ret = cam_test_phase3_run();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 3 %#x\n", s32Ret);
			cam_vi_bringup_deinit();
			return 1;
		}
	} else if (g_cam_phase == 4) {
		s32Ret = cam_test_phase4_run();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 4 %#x\n", s32Ret);
			cam_vi_bringup_deinit();
			return 1;
		}
	} else if (g_cam_phase == 5) {
		s32Ret = cam_test_phase5_run(stream_sec);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 5 %#x\n", s32Ret);
			cam_vi_bringup_deinit();
			return 1;
		}
	} else if (g_cam_phase == 6) {
		s32Ret = cam_test_phase6_validate();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 6 %#x\n", s32Ret);
			cam_vi_bringup_deinit();
			return 1;
		}
		printf("holding %d s (dual ISP running)...\n", hold_sec);
		for (int i = 0; i < hold_sec && !g_cam_stop; i++)
			sleep(1);
	} else if (g_cam_phase == 7) {
		s32Ret = cam_test_phase7_run();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 7 %#x\n", s32Ret);
			cam_vi_bringup_deinit();
			return 1;
		}
	} else if (g_cam_phase == 8) {
		s32Ret = cam_test_phase8_run();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 8 %#x\n", s32Ret);
			cam_vi_bringup_deinit();
			return 1;
		}
		printf("my_cam_test: PASSED (phase 8)\n");
		fflush(stdout);
		_exit(0);
	} else {
		printf("holding %d s (ISP running)...\n", hold_sec);
		for (int i = 0; i < hold_sec && !g_cam_stop; i++)
			sleep(1);
	}

	cam_vi_bringup_deinit();
	printf("my_cam_test: PASSED (phase %d)\n", g_cam_phase);
	return 0;
}
