/*
 * my_cam_test.c — EdgeEye 摄像头渐进验收入口（测试程序，非产品库）
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "cam_app_context.h"
#include "cam_pipeline_mode.h"
#include "cam_test_config.h"
#include "cam_test_phases.h"
#include "cam_vi_bringup.h"

static volatile sig_atomic_t g_test_stop;
static int g_test_phase = CAM_DEFAULT_PHASE;
static int g_test_out_path_set;
static char g_test_out_path[256] = CAM_DEFAULT_YUV_PATH;

static void handle_signal(int signo)
{
	(void)signo;
	g_test_stop = 1;
	g_cam_stop = 1;
}

static void usage(const char *prog)
{
	printf("Usage: %s [-p PHASE] [-s SECONDS] [-o PATH] [-P PORT] [-u URL] [-v]\n",
	       prog);
	printf("  sensor_cfg.ini dev_num=1 -> single cam; dev_num=2 -> dual cam\n");
	printf("  Phase 2: init VI/ISP, hold (single or dual)\n");
	printf("  Phase 3: VI -> VPSS, capture NV12 (1 or 2 files)\n");
	printf("  Phase 4: VI -> VPSS -> VENC, write H.264 (1 or 2 files)\n");
	printf("  Phase 5: VI -> VPSS -> VENC -> RTSP (cam0; dual adds cam1)\n");
	printf("  Phase 6: alias of phase 2 hold (dual ini only, for scripts)\n");
	printf("  Phase 7: alias of phase 3 (dual scripts)\n");
	printf("  Phase 8: alias of phase 4 (dual scripts)\n");
	printf("  -p  2, 3, 4, 5, 6, 7, or 8 (default %d)\n", CAM_DEFAULT_PHASE);
	printf("  -o  single-cam phase 3/4 output (default %s / %s)\n",
	       CAM_DEFAULT_YUV_PATH, CAM_DEFAULT_H264_PATH);
	printf("  -s  phase 2/6 hold seconds (default %d); phase 5 stream seconds (default %d)\n",
	       CAM_DEFAULT_HOLD_SEC, CAM_DEFAULT_STREAM_SEC);
	printf("  -P  RTSP port for phase 5 (default %d)\n", CAM_DEFAULT_RTSP_PORT);
	printf("  -u  RTSP URL path for single-cam phase 5 (default %s)\n",
	       CAM_DEFAULT_RTSP_URL);
	printf("  -v  VI/ISP/VPSS/VENC/VB debug logs\n");
}

static CVI_S32 run_isp_hold(int hold_sec, int phase_label)
{
	printf("holding %d s (ISP running, %s)...\n", hold_sec,
	       cam_is_dual() ? "dual" : "single");
	for (int i = 0; i < hold_sec && !g_test_stop; i++)
		sleep(1);
	if (g_test_stop)
		return CVI_FAILURE;

	printf("%s: PASSED (phase %d)\n", CAM_TEST_LOG_TAG, phase_label);
	fflush(stdout);
	if (cam_test_should_fast_exit(phase_label, cam_is_dual()))
		_exit(0);
	return CVI_SUCCESS;
}

int main(int argc, char **argv)
{
	int hold_sec = CAM_DEFAULT_HOLD_SEC;
	int stream_sec = CAM_DEFAULT_STREAM_SEC;
	cam_vi_bringup_opts bringup_opts;
	int opt;
	CVI_S32 s32Ret;

	for (opt = 1; opt < argc; opt++) {
		if (strcmp(argv[opt], "-h") == 0 || strcmp(argv[opt], "--help") == 0) {
			usage(argv[0]);
			return 0;
		}
		if (strcmp(argv[opt], "-p") == 0 && opt + 1 < argc) {
			g_test_phase = atoi(argv[++opt]);
			if (g_test_phase < 2 || g_test_phase > 8) {
				printf("%s: invalid phase %d (use 2-8)\n",
				       CAM_TEST_LOG_TAG, g_test_phase);
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
			strncpy(g_test_out_path, argv[++opt], sizeof(g_test_out_path) - 1);
			g_test_out_path[sizeof(g_test_out_path) - 1] = '\0';
			g_test_out_path_set = 1;
			continue;
		}
		if (strcmp(argv[opt], "-P") == 0 && opt + 1 < argc) {
			g_cam_rtsp_port = atoi(argv[++opt]);
			if (g_cam_rtsp_port < 1 || g_cam_rtsp_port > 65535) {
				printf("%s: invalid RTSP port %d\n",
				       CAM_TEST_LOG_TAG, g_cam_rtsp_port);
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

	if (!g_test_out_path_set) {
		if (g_test_phase == 4 || g_test_phase == 8)
			strncpy(g_test_out_path, CAM_DEFAULT_H264_PATH, sizeof(g_test_out_path) - 1);
		else if (g_test_phase == 3 || g_test_phase == 7)
			strncpy(g_test_out_path, CAM_DEFAULT_YUV_PATH, sizeof(g_test_out_path) - 1);
		g_test_out_path[sizeof(g_test_out_path) - 1] = '\0';
	}

	printf("=== EdgeEye %s (phase %d) ===\n", CAM_TEST_LOG_TAG, g_test_phase);

	bringup_opts = cam_test_bringup_opts(g_test_phase);
	s32Ret = cam_vi_bringup_init(&bringup_opts);
	if (s32Ret != CVI_SUCCESS) {
		printf("%s: FAILED init %#x\n", CAM_TEST_LOG_TAG, s32Ret);
		return 1;
	}

	switch (g_test_phase) {
	case 2:
		s32Ret = run_isp_hold(hold_sec, 2);
		break;
	case 3:
	case 7:
		s32Ret = cam_test_capture_yuv_run(g_test_out_path);
		break;
	case 4:
	case 8:
		s32Ret = cam_test_capture_h264_run(g_test_out_path);
		break;
	case 5:
		s32Ret = cam_test_rtsp_run(stream_sec);
		break;
	case 6:
		s32Ret = cam_test_phase6_validate();
		if (s32Ret == CVI_SUCCESS)
			s32Ret = run_isp_hold(hold_sec, 6);
		break;
	default:
		printf("%s: invalid phase %d\n", CAM_TEST_LOG_TAG, g_test_phase);
		s32Ret = CVI_FAILURE;
		break;
	}

	if (s32Ret != CVI_SUCCESS) {
		printf("%s: FAILED phase %d %#x\n", CAM_TEST_LOG_TAG, g_test_phase, s32Ret);
		cam_vi_bringup_deinit();
		return 1;
	}

	if (g_test_phase == 8 && cam_is_dual()) {
		printf("%s: PASSED (phase 8)\n", CAM_TEST_LOG_TAG);
		fflush(stdout);
		_exit(0);
	}

	cam_vi_bringup_deinit();
	printf("%s: PASSED (phase %d)\n", CAM_TEST_LOG_TAG, g_test_phase);
	return 0;
}
