/*
 * my_cam_test.c — EdgeEye 摄像头学习程序（阶段 2～5 渐进）
 *
 * 阶段 2：仅 VI/ISP 初始化
 * 阶段 3：VI → VPSS，抓一帧 NV12 YUV 存盘
 * 阶段 4：VI → VPSS → VENC，写 H.264 文件
 * 阶段 5：VI → VPSS → VENC → RTSP 实时预览
 * 阶段 6：双摄 VI/ISP 初始化（须 sensor_cfg.ini dev_num=2）
 * 阶段 7：双摄 VI → VPSS，各抓一帧 NV12
 *
 * 板上用法：
 *   ./my_cam_test -p 3 -o /tmp/frame.yuv
 *   ./my_cam_test -p 4 -o /tmp/frame.h264
 *   ./my_cam_test -p 5 -s 30 -P 8554 -u cam0
 *   ./my_cam_test -p 6 -s 10
 */

#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "sample_comm.h"
#include "cvi_isp.h"
#include "cvi_sys.h"
#include "cvi_venc.h"
#include "rtsp.h"

#define DEFAULT_HOLD_SEC   10
#define DEFAULT_PHASE      2
#define DEFAULT_YUV_PATH   "/tmp/frame.yuv"
#define DEFAULT_H264_PATH  "/tmp/frame.h264"
#define DEFAULT_RTSP_PORT  8554
#define DEFAULT_RTSP_URL   "cam0"
#define DEFAULT_STREAM_SEC 30
#define VPSS_GRP_ID       0
#define VPSS_CHN_ID       VPSS_CHN0
#define VENC_CHN_ID       0
#define FRAME_WAIT_MS     3000
#define ISP_SETTLE_SEC    2
#define VENC_SAVE_STREAMS 30
#define RTSP_MIN_FRAMES    30
#define DUAL_ISP_SETTLE_SEC 6
#define MAX_CAM            2
#define DUAL_CAM0_YUV      "/tmp/cam0.yuv"
#define DUAL_CAM1_YUV      "/tmp/cam1.yuv"

static SAMPLE_VI_CONFIG_S g_stViConfig;
static volatile sig_atomic_t g_stop;
static int g_verbose;
static int g_phase = DEFAULT_PHASE;
static int g_out_path_set;
static char g_out_path[256] = DEFAULT_YUV_PATH;
static int g_rtsp_port = DEFAULT_RTSP_PORT;
static char g_rtsp_url[128] = DEFAULT_RTSP_URL;
static CVI_BOOL g_vpss_up;
static int g_vpss_grp_mask;
static CVI_BOOL g_dual_media_mode;
static CVI_BOOL g_venc_up;
static CVI_BOOL g_rtsp_up;
static CVI_RTSP_CTX *g_rtsp_ctx;
static CVI_RTSP_SESSION *g_rtsp_session;
static chnInputCfg g_venc_ic;

/* 双摄在线 VPSS：与 cvi_rtsp vpss_helper.cpp init_vi 一致 */
static void prepare_dual_vi_online_config(SAMPLE_VI_CONFIG_S *pstViConfig)
{
	for (CVI_S32 i = 0; i < pstViConfig->s32WorkingViNum; i++) {
		pstViConfig->astViInfo[i].stChnInfo.enCompressMode = COMPRESS_MODE_TILE;
		pstViConfig->astViInfo[i].stPipeInfo.enMastPipeMode = VI_OFFLINE_VPSS_OFFLINE;
		pstViConfig->astViInfo[i].stPipeInfo.aPipe[0] = i;
		pstViConfig->astViInfo[i].stPipeInfo.aPipe[1] = -1;
		pstViConfig->astViInfo[i].stPipeInfo.aPipe[2] = -1;
		pstViConfig->astViInfo[i].stPipeInfo.aPipe[3] = -1;
	}
}

static CVI_S32 setup_dual_media_mode(void)
{
	VI_VPSS_MODE_S stVIVPSSMode;
	VPSS_MODE_S stVPSSMode;
	CVI_S32 s32Ret;

	memset(&stVIVPSSMode, 0, sizeof(stVIVPSSMode));
	memset(&stVPSSMode, 0, sizeof(stVPSSMode));

	stVIVPSSMode.aenMode[0] = VI_OFFLINE_VPSS_ONLINE;
	stVIVPSSMode.aenMode[1] = VI_OFFLINE_VPSS_ONLINE;

	s32Ret = CVI_SYS_SetVIVPSSMode(&stVIVPSSMode);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: SetVIVPSSMode failed %#x\n", s32Ret);
		return s32Ret;
	}

	stVPSSMode.enMode = VPSS_MODE_DUAL;
	stVPSSMode.aenInput[0] = VPSS_INPUT_MEM;
	stVPSSMode.ViPipe[0] = 0;
	stVPSSMode.aenInput[1] = VPSS_INPUT_ISP;
	stVPSSMode.ViPipe[1] = 0;

	s32Ret = CVI_SYS_SetVPSSModeEx(&stVPSSMode);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: SetVPSSModeEx failed %#x\n", s32Ret);
		return s32Ret;
	}

	g_dual_media_mode = CVI_TRUE;
	printf("my_cam_test: dual VI-VPSS online (VPSS_INPUT_MEM+ISP, ViPipe[1]=0)\n");
	return CVI_SUCCESS;
}

static void handle_signal(int signo)
{
	(void)signo;
	g_stop = 1;
}

static CVI_S32 setup_vb_pool(const SAMPLE_INI_CFG_S *pstIniCfg,
			     SAMPLE_VI_CONFIG_S *pstViConfig,
			     VB_CONFIG_S *pstVbConf)
{
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	CVI_U32 u32BlkSize, u32BlkRotSize;
	CVI_U32 vb_cnt = 3;

	if (g_phase >= 4 && g_phase <= 5)
		vb_cnt = 8;
	else if (g_phase == 3 || g_phase == 7)
		vb_cnt = 8;

	memset(pstVbConf, 0, sizeof(*pstVbConf));

	for (CVI_S32 i = 0; i < pstViConfig->s32WorkingViNum; i++) {
		CVI_BOOL create_new = CVI_TRUE;
		CVI_S32 s32Ret;

		s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(pstIniCfg->enSnsType[i], &enPicSize);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: GetSizeBySensor failed %#x\n", s32Ret);
			return s32Ret;
		}

		s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, &stSize);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: GetPicSize failed %#x\n", s32Ret);
			return s32Ret;
		}

		u32BlkSize = COMMON_GetPicBufferSize(stSize.u32Width, stSize.u32Height,
						     pstViConfig->astViInfo[i].stChnInfo.enPixFormat,
						     DATA_BITWIDTH_8, COMPRESS_MODE_NONE,
						     DEFAULT_ALIGN);
		u32BlkRotSize = COMMON_GetPicBufferSize(stSize.u32Height, stSize.u32Width,
							pstViConfig->astViInfo[i].stChnInfo.enPixFormat,
							DATA_BITWIDTH_8, COMPRESS_MODE_NONE,
							DEFAULT_ALIGN);
		if (u32BlkRotSize > u32BlkSize)
			u32BlkSize = u32BlkRotSize;

		for (CVI_U32 j = 0; j < pstVbConf->u32MaxPoolCnt; j++) {
			if (pstVbConf->astCommPool[j].u32BlkSize == u32BlkSize) {
				/* 双摄 phase7 在线 VPSS 须每路独立 pool（对齐 vendor init_vi） */
				if (!(g_phase == 7 && pstIniCfg->devNum >= 2)) {
					pstVbConf->astCommPool[j].u32BlkCnt += vb_cnt;
					create_new = CVI_FALSE;
				}
				break;
			}
		}

		if (create_new) {
			CVI_U32 idx = pstVbConf->u32MaxPoolCnt;

			pstVbConf->astCommPool[idx].u32BlkSize = u32BlkSize;
			pstVbConf->astCommPool[idx].u32BlkCnt = vb_cnt;
			pstVbConf->astCommPool[idx].enRemapMode = VB_REMAP_MODE_CACHED;
			printf("VB pool[%u]: %ux%u blk=%u size=%u\n", idx,
			       stSize.u32Width, stSize.u32Height, vb_cnt, u32BlkSize);
			pstVbConf->u32MaxPoolCnt++;
		}
	}

	if (pstVbConf->u32MaxPoolCnt == 1)
		pstVbConf->astCommPool[0].u32BlkCnt += 2;

	return CVI_SUCCESS;
}

static void log_set_verbose(void)
{
	LOG_LEVEL_CONF_S log_conf;

	log_conf.enModId = CVI_ID_LOG;
	log_conf.s32Level = CVI_DBG_DEBUG;
	CVI_LOG_SetLevelConf(&log_conf);

	log_conf.enModId = CVI_ID_VI;
	CVI_LOG_SetLevelConf(&log_conf);

	log_conf.enModId = CVI_ID_ISP;
	CVI_LOG_SetLevelConf(&log_conf);

	log_conf.enModId = CVI_ID_VB;
	CVI_LOG_SetLevelConf(&log_conf);

	log_conf.enModId = CVI_ID_VPSS;
	CVI_LOG_SetLevelConf(&log_conf);

	log_conf.enModId = CVI_ID_VENC;
	CVI_LOG_SetLevelConf(&log_conf);
}

static CVI_S32 vi_init(void)
{
	MMF_VERSION_S stVersion;
	SAMPLE_INI_CFG_S stIniCfg;
	SAMPLE_VI_CONFIG_S stViConfig;
	VB_CONFIG_S stVbConf;
	LOG_LEVEL_CONF_S log_conf;
	CVI_S32 s32Ret;

	CVI_SYS_GetVersion(&stVersion); /* 查询 MMF 版本 */
	printf("MMF Version: %s\n", stVersion.version);

	log_conf.enModId = CVI_ID_LOG;
	log_conf.s32Level = g_verbose ? CVI_DBG_DEBUG : CVI_DBG_INFO;
	CVI_LOG_SetLevelConf(&log_conf); /* 设置日志级别 */
	if (g_verbose)
		log_set_verbose();

	s32Ret = SAMPLE_COMM_VI_ParseIni(&stIniCfg); /* 解析 sensor_cfg.ini */
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: ParseIni failed (check /mnt/data/sensor_cfg.ini)\n");
		return s32Ret;
	}
	printf("sensor_cfg.ini: dev_num=%u\n", stIniCfg.devNum);

	CVI_VI_SetDevNum(stIniCfg.devNum); /* 设置 VI 设备数 */

	s32Ret = SAMPLE_COMM_VI_IniToViCfg(&stIniCfg, &stViConfig); /* ini → VI 配置 */
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	memcpy(&g_stViConfig, &stViConfig, sizeof(g_stViConfig));

	if (stIniCfg.devNum >= 2 && g_phase >= 7)
		prepare_dual_vi_online_config(&stViConfig);

	s32Ret = setup_vb_pool(&stIniCfg, &stViConfig, &stVbConf);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_Init(&stVbConf); /* 初始化 VB 与系统 */
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: SYS_Init failed %#x\n", s32Ret);
		return s32Ret;
	}

	if (stIniCfg.devNum >= 2 && g_phase >= 7) {
		s32Ret = setup_dual_media_mode();
		if (s32Ret != CVI_SUCCESS) {
			SAMPLE_COMM_SYS_Exit();
			return s32Ret;
		}
	}

	s32Ret = SAMPLE_PLAT_VI_INIT(&stViConfig); /* 启动 VI + ISP */
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VI_Init failed %#x\n", s32Ret);
		SAMPLE_COMM_SYS_Exit();
		return s32Ret;
	}

	if (stIniCfg.devNum >= 2 && g_phase >= 7) {
		for (CVI_S32 i = 0; i < stViConfig.s32WorkingViNum; i++) {
			ISP_PUB_ATTR_S stPubAttr = {0};
			VI_PIPE pipe = stViConfig.astViInfo[i].stPipeInfo.aPipe[0];

			CVI_ISP_GetPubAttr(pipe, &stPubAttr);
			printf("my_cam_test: pipe%d ISP FPS %.2f\n", pipe, stPubAttr.f32FrameRate);
		}
	}

	printf("my_cam_test: VI/ISP init OK (look for sensor Init OK above)\n");
	return CVI_SUCCESS;
}

static CVI_S32 phase6a_validate(void)
{
	if (g_stViConfig.s32WorkingViNum < 2) {
		printf("my_cam_test: phase 6 needs dev_num=2 in sensor_cfg.ini (working=%d)\n",
		       g_stViConfig.s32WorkingViNum);
		return CVI_FAILURE;
	}

	printf("my_cam_test: dual VI/ISP OK (%d sensors active)\n",
	       g_stViConfig.s32WorkingViNum);
	return CVI_SUCCESS;
}

static CVI_S32 vpss_init_grp(VPSS_GRP vpss_grp, const SIZE_S *pstSize, CVI_U32 depth,
			     CVI_U8 vpss_dev)
{
	VPSS_GRP_ATTR_S stVpssGrpAttr;
	VPSS_CHN_ATTR_S astVpssChnAttr[VPSS_MAX_PHY_CHN_NUM];
	CVI_BOOL abChnEnable[VPSS_MAX_PHY_CHN_NUM] = {0};
	CVI_S32 s32Ret;

	memset(&stVpssGrpAttr, 0, sizeof(stVpssGrpAttr));
	memset(astVpssChnAttr, 0, sizeof(astVpssChnAttr));

	stVpssGrpAttr.stFrameRate.s32SrcFrameRate = -1;
	stVpssGrpAttr.stFrameRate.s32DstFrameRate = -1;
	stVpssGrpAttr.enPixelFormat = SAMPLE_PIXEL_FORMAT;
	stVpssGrpAttr.u32MaxW = pstSize->u32Width;
	stVpssGrpAttr.u32MaxH = pstSize->u32Height;
	stVpssGrpAttr.u8VpssDev = vpss_dev;

	astVpssChnAttr[VPSS_CHN_ID].u32Width = pstSize->u32Width;
	astVpssChnAttr[VPSS_CHN_ID].u32Height = pstSize->u32Height;
	astVpssChnAttr[VPSS_CHN_ID].enVideoFormat = VIDEO_FORMAT_LINEAR;
	astVpssChnAttr[VPSS_CHN_ID].enPixelFormat = SAMPLE_PIXEL_FORMAT;
	astVpssChnAttr[VPSS_CHN_ID].stFrameRate.s32SrcFrameRate = -1;
	astVpssChnAttr[VPSS_CHN_ID].stFrameRate.s32DstFrameRate = -1;
	astVpssChnAttr[VPSS_CHN_ID].u32Depth = depth;
	astVpssChnAttr[VPSS_CHN_ID].bMirror = CVI_FALSE;
	astVpssChnAttr[VPSS_CHN_ID].bFlip = CVI_FALSE;
	astVpssChnAttr[VPSS_CHN_ID].stAspectRatio.enMode = ASPECT_RATIO_NONE;
	astVpssChnAttr[VPSS_CHN_ID].stNormalize.bEnable = CVI_FALSE;

	abChnEnable[VPSS_CHN_ID] = CVI_TRUE;

	s32Ret = SAMPLE_COMM_VPSS_Init(vpss_grp, abChnEnable, &stVpssGrpAttr, astVpssChnAttr);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VPSS_Init grp%d failed %#x\n", vpss_grp, s32Ret);
		return s32Ret;
	}

	s32Ret = SAMPLE_COMM_VPSS_Start(vpss_grp, abChnEnable, &stVpssGrpAttr,
					astVpssChnAttr);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VPSS_Start grp%d failed %#x\n", vpss_grp, s32Ret);
		return s32Ret;
	}

	if (g_dual_media_mode) {
		s32Ret = CVI_VPSS_SetGrpParamfromBin(vpss_grp, VPSS_CHN_ID);
		if (s32Ret != CVI_SUCCESS)
			printf("my_cam_test: SetGrpParamfromBin grp%d %#x (non-fatal)\n",
			       vpss_grp, s32Ret);
	}

	g_vpss_grp_mask |= (1 << vpss_grp);
	g_vpss_up = CVI_TRUE;
	printf("my_cam_test: VPSS grp%d %ux%u ready\n", vpss_grp,
	       pstSize->u32Width, pstSize->u32Height);
	return CVI_SUCCESS;
}

static CVI_S32 vpss_init(const SIZE_S *pstSize, CVI_U32 depth)
{
	return vpss_init_grp(VPSS_GRP_ID, pstSize, depth, 0);
}

static CVI_S32 vi_bind_vpss_cam(int cam_idx)
{
	VI_PIPE vi_pipe = g_stViConfig.astViInfo[cam_idx].stPipeInfo.aPipe[0];
	VI_CHN vi_chn = g_stViConfig.astViInfo[cam_idx].stChnInfo.ViChn;
	VPSS_GRP vpss_grp = (VPSS_GRP)cam_idx;
	CVI_S32 s32Ret;

	s32Ret = SAMPLE_COMM_VI_Bind_VPSS(vi_pipe, vi_chn, vpss_grp);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VI_Bind_VPSS cam%d failed %#x (pipe=%d chn=%d)\n",
		       cam_idx, s32Ret, vi_pipe, vi_chn);
		return s32Ret;
	}

	printf("my_cam_test: cam%d VI pipe %d chn %d -> VPSS grp %d\n",
	       cam_idx, vi_pipe, vi_chn, vpss_grp);
	return CVI_SUCCESS;
}

static CVI_S32 vi_bind_vpss(void)
{
	return vi_bind_vpss_cam(0);
}

static CVI_S32 save_nv12_frame(const VIDEO_FRAME_INFO_S *pstFrame, const char *path)
{
	FILE *fp;
	size_t image_size;
	CVI_VOID *vir_addr;
	CVI_U32 plane_offset;
	CVI_U32 u32_luma, u32_chroma;

	image_size = pstFrame->stVFrame.u32Length[0] + pstFrame->stVFrame.u32Length[1]
		+ pstFrame->stVFrame.u32Length[2];

	fp = fopen(path, "wb");
	if (!fp) {
		printf("my_cam_test: fopen(%s) failed\n", path);
		return CVI_FAILURE;
	}

	u32_luma = pstFrame->stVFrame.u32Stride[0] * pstFrame->stVFrame.u32Height;
	u32_chroma = pstFrame->stVFrame.u32Stride[1] * pstFrame->stVFrame.u32Height / 2;

	vir_addr = CVI_SYS_Mmap(pstFrame->stVFrame.u64PhyAddr[0], image_size);
	if (!vir_addr) {
		fclose(fp);
		printf("my_cam_test: Mmap frame failed\n");
		return CVI_FAILURE;
	}

	CVI_SYS_IonInvalidateCache(pstFrame->stVFrame.u64PhyAddr[0], vir_addr, image_size);

	plane_offset = 0;
	for (int i = 0; i < 3; i++) {
		if (pstFrame->stVFrame.u32Length[i] == 0)
			continue;

		CVI_U8 *plane = (CVI_U8 *)vir_addr + plane_offset;
		size_t write_len = (i == 0) ? u32_luma : u32_chroma;

		if (fwrite(plane, write_len, 1, fp) != 1) {
			CVI_SYS_Munmap(vir_addr, image_size);
			fclose(fp);
			printf("my_cam_test: fwrite plane %d failed\n", i);
			return CVI_FAILURE;
		}
		plane_offset += pstFrame->stVFrame.u32Length[i];
	}

	CVI_SYS_Munmap(vir_addr, image_size);
	fclose(fp);

	printf("my_cam_test: saved %ux%u NV12 -> %s (%zu bytes payload)\n",
	       pstFrame->stVFrame.u32Width, pstFrame->stVFrame.u32Height,
	       path, image_size);
	return CVI_SUCCESS;
}

static CVI_S32 capture_vpss_frame_grp(VPSS_GRP vpss_grp, const char *path,
				      CVI_BOOL do_settle)
{
	VIDEO_FRAME_INFO_S stFrame;
	CVI_S32 s32Ret;
	int attempt;

	memset(&stFrame, 0, sizeof(stFrame));

	if (do_settle) {
		printf("my_cam_test: waiting %d s for AE/AWB...\n", ISP_SETTLE_SEC);
		for (int i = 0; i < ISP_SETTLE_SEC && !g_stop; i++)
			sleep(1);
		if (g_stop)
			return CVI_FAILURE;
	}

	for (attempt = 1; attempt <= 10; attempt++) {
		s32Ret = CVI_VPSS_GetChnFrame(vpss_grp, VPSS_CHN_ID, &stFrame, FRAME_WAIT_MS);
		if (s32Ret == CVI_SUCCESS)
			break;
		printf("my_cam_test: grp%d GetChnFrame attempt %d failed %#x\n",
		       vpss_grp, attempt, s32Ret);
	}

	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = save_nv12_frame(&stFrame, path);
	if (CVI_VPSS_ReleaseChnFrame(vpss_grp, VPSS_CHN_ID, &stFrame) != CVI_SUCCESS)
		printf("my_cam_test: grp%d ReleaseChnFrame failed\n", vpss_grp);

	return s32Ret;
}

static CVI_S32 capture_vpss_frame(const char *path)
{
	return capture_vpss_frame_grp(VPSS_GRP_ID, path, CVI_TRUE);
}

static CVI_S32 phase3_run(void)
{
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	CVI_S32 s32Ret;

	s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
		g_stViConfig.astViInfo[0].stSnsInfo.enSnsType, &enPicSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, &stSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = vpss_init(&stSize, 1);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = vi_bind_vpss();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return capture_vpss_frame(g_out_path);
}

static CVI_S32 phase7_run(void)
{
	static const char *paths[MAX_CAM] = { DUAL_CAM0_YUV, DUAL_CAM1_YUV };
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	CVI_S32 s32Ret;
	int cam;

	s32Ret = phase6a_validate();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	for (cam = 0; cam < g_stViConfig.s32WorkingViNum; cam++) {
		VPSS_GRP vpss_grp = g_dual_media_mode ?
			(cam == 0 ? VPSS_ONLINE_GRP_0 : VPSS_ONLINE_GRP_1) : (VPSS_GRP)cam;
		CVI_U8 vpss_dev = g_dual_media_mode ? 1 : 0;

		s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
			g_stViConfig.astViInfo[cam].stSnsInfo.enSnsType, &enPicSize);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;

		s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, &stSize);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;

		s32Ret = vpss_init_grp(vpss_grp, &stSize, 1, vpss_dev);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;

		if (!g_dual_media_mode) {
			s32Ret = vi_bind_vpss_cam(cam);
			if (s32Ret != CVI_SUCCESS)
				return s32Ret;
		} else if (cam == 0) {
			s32Ret = vi_bind_vpss_cam(cam);
			if (s32Ret != CVI_SUCCESS)
				return s32Ret;
			printf("my_cam_test: cam0 grp0 online u8VpssDev=1 + VI bind\n");
		} else {
			printf("my_cam_test: cam1 grp1 online u8VpssDev=1 (no VI bind)\n");
		}
	}

	printf("my_cam_test: waiting %d s for dual AE/AWB...\n", DUAL_ISP_SETTLE_SEC);
	for (int i = 0; i < DUAL_ISP_SETTLE_SEC && !g_stop; i++)
		sleep(1);
	if (g_stop)
		return CVI_FAILURE;

	for (cam = 0; cam < g_stViConfig.s32WorkingViNum; cam++) {
		VPSS_GRP vpss_grp = g_dual_media_mode ?
			(cam == 0 ? VPSS_ONLINE_GRP_0 : VPSS_ONLINE_GRP_1) : (VPSS_GRP)cam;

		s32Ret = capture_vpss_frame_grp(vpss_grp, paths[cam], CVI_FALSE);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: cam%d capture failed %#x\n", cam, s32Ret);
			return s32Ret;
		}
	}

	printf("my_cam_test: dual VPSS capture OK\n");
	return CVI_SUCCESS;
}

static void venc_fill_h264_cbr_defaults(chnInputCfg *pIc, int continuous)
{
	SAMPLE_COMM_VENC_InitChnInputCfg(pIc); /* 填充 VENC 通道默认字段 */
	strcpy(pIc->codec, "264");
	pIc->bind_mode = VENC_BIND_VPSS;
	pIc->vpssGrp = VPSS_GRP_ID;
	pIc->vpssChn = VPSS_CHN_ID;
	pIc->num_frames = continuous ? -1 : 90;
	pIc->getstream_timeout = FRAME_WAIT_MS;
	pIc->u32Profile = CVI_H264_PROFILE_DEFAULT;
	pIc->rcMode = SAMPLE_RC_CBR;
	pIc->statTime = 2;
	pIc->gop = 30;
	pIc->gopMode = VENC_GOPMODE_NORMALP;
	pIc->bitrate = 4096;
	pIc->maxbitrate = 5000;
	pIc->firstFrmstartQp = 34;
	pIc->initialDelay = CVI_INITIAL_DELAY_DEFAULT;
	pIc->u32ThrdLv = CVI_H26X_THRDLV_DEFAULT;
	pIc->maxIprop = CVI_H26X_MAX_I_PROP_DEFAULT;
	pIc->minIprop = CVI_H26X_MIN_I_PROP_DEFAULT;
	pIc->h264ChromaQpOffset = 0;
	pIc->u32IntraCost = CVI_H26X_INTRACOST_DEFAULT;
	pIc->u32RowQpDelta = CVI_H26X_ROW_QP_DELTA_DEFAULT;
	pIc->maxQp = DEF_264_MAXQP;
	pIc->minQp = DEF_264_MINQP;
	pIc->maxIqp = DEF_264_MAXIQP;
	pIc->minIqp = DEF_264_MINIQP;
	pIc->framerate = 30;
	pIc->srcFramerate = 30;
	pIc->bCreateChn = CVI_FALSE;
}

static CVI_S32 venc_init(PIC_SIZE_E enPicSize, int continuous)
{
	VENC_GOP_ATTR_S stGop;
	CVI_S32 s32Ret;

	venc_fill_h264_cbr_defaults(&g_venc_ic, continuous);

	s32Ret = SAMPLE_COMM_VENC_GetGopAttr(VENC_GOPMODE_NORMALP, &stGop);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VENC_GetGopAttr failed %#x\n", s32Ret);
		return s32Ret;
	}

	s32Ret = SAMPLE_COMM_VENC_Start(&g_venc_ic, VENC_CHN_ID, PT_H264, enPicSize,
					SAMPLE_RC_CBR, CVI_H264_PROFILE_DEFAULT,
					CVI_FALSE, &stGop);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VENC_Start failed %#x\n", s32Ret);
		return s32Ret;
	}

	g_venc_up = CVI_TRUE;
	printf("my_cam_test: VENC H264 ready (pic_size=%d)\n", enPicSize);
	return CVI_SUCCESS;
}

static CVI_S32 capture_venc_stream(const char *path)
{
	FILE *fp;
	VENC_STREAM_S stStream;
	VENC_CHN_STATUS_S stStat;
	size_t total_bytes = 0;
	int streams = 0;
	CVI_S32 s32Ret;

	fp = fopen(path, "wb");
	if (!fp) {
		printf("my_cam_test: fopen(%s) failed\n", path);
		return CVI_FAILURE;
	}

	printf("my_cam_test: waiting %d s for AE/AWB...\n", ISP_SETTLE_SEC);
	for (int i = 0; i < ISP_SETTLE_SEC && !g_stop; i++)
		sleep(1);
	if (g_stop) {
		fclose(fp);
		return CVI_FAILURE;
	}

	for (int attempt = 0; attempt < VENC_SAVE_STREAMS && !g_stop; attempt++) {
		memset(&stStream, 0, sizeof(stStream));
		memset(&stStat, 0, sizeof(stStat));

		s32Ret = CVI_VENC_QueryStatus(VENC_CHN_ID, &stStat);
		if (s32Ret != CVI_SUCCESS || stStat.u32CurPacks == 0) {
			usleep(100000);
			continue;
		}

		stStream.pstPack = calloc(stStat.u32CurPacks, sizeof(VENC_PACK_S));
		if (!stStream.pstPack) {
			fclose(fp);
			return CVI_FAILURE;
		}

		s32Ret = CVI_VENC_GetStream(VENC_CHN_ID, &stStream,
					    g_venc_ic.getstream_timeout);
		if (s32Ret != CVI_SUCCESS) {
			free(stStream.pstPack);
			printf("my_cam_test: GetStream attempt %d failed %#x\n",
			       attempt + 1, s32Ret);
			usleep(100000);
			continue;
		}

		for (CVI_U32 i = 0; i < stStream.u32PackCount; i++) {
			VENC_PACK_S *pack = &stStream.pstPack[i];

			total_bytes += pack->u32Len - pack->u32Offset;
		}

		s32Ret = SAMPLE_COMM_VENC_SaveStream(PT_H264, fp, &stStream);
		CVI_VENC_ReleaseStream(VENC_CHN_ID, &stStream);
		free(stStream.pstPack);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: SaveStream failed %#x\n", s32Ret);
			fclose(fp);
			return s32Ret;
		}

		streams++;
	}

	fclose(fp);

	if (streams == 0 || total_bytes < 1024) {
		printf("my_cam_test: H264 too small (streams=%d bytes=%zu)\n",
		       streams, total_bytes);
		return CVI_FAILURE;
	}

	printf("my_cam_test: saved H264 -> %s (%zu bytes, %d streams)\n",
	       path, total_bytes, streams);
	return CVI_SUCCESS;
}

static CVI_S32 phase4_run(void)
{
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	CVI_S32 s32Ret;

	s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
		g_stViConfig.astViInfo[0].stSnsInfo.enSnsType, &enPicSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, &stSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = vpss_init(&stSize, 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = vi_bind_vpss();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = venc_init(enPicSize, 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return capture_venc_stream(g_out_path);
}

static CVI_S32 rtsp_init(void)
{
	CVI_RTSP_CONFIG config;
	CVI_RTSP_SESSION_ATTR attr;

	memset(&config, 0, sizeof(config));
	config.port = g_rtsp_port;
	config.timeout = 60;
	config.maxConnNum = 8;

	if (CVI_RTSP_Create(&g_rtsp_ctx, &config) != 0) {
		printf("my_cam_test: CVI_RTSP_Create failed\n");
		return CVI_FAILURE;
	}

	memset(&attr, 0, sizeof(attr));
	attr.video.codec = RTSP_VIDEO_H264;
	attr.video.bitrate = g_venc_ic.bitrate;
	strncpy(attr.name, g_rtsp_url, sizeof(attr.name) - 1);

	if (CVI_RTSP_CreateSession(g_rtsp_ctx, &attr, &g_rtsp_session) != 0) {
		printf("my_cam_test: CVI_RTSP_CreateSession failed\n");
		CVI_RTSP_Destroy(&g_rtsp_ctx);
		return CVI_FAILURE;
	}

	if (CVI_RTSP_Start(g_rtsp_ctx) != 0) {
		printf("my_cam_test: CVI_RTSP_Start failed\n");
		CVI_RTSP_DestroySession(g_rtsp_ctx, g_rtsp_session);
		CVI_RTSP_Destroy(&g_rtsp_ctx);
		return CVI_FAILURE;
	}

	g_rtsp_up = CVI_TRUE;
	printf("my_cam_test: RTSP ready rtsp://<board>:%d/%s\n",
	       g_rtsp_port, g_rtsp_url);
	printf("Mac: ffplay -rtsp_transport tcp rtsp://192.168.42.1:%d/%s\n",
	       g_rtsp_port, g_rtsp_url);
	return CVI_SUCCESS;
}

static CVI_S32 stream_venc_to_rtsp(int stream_sec)
{
	VENC_STREAM_S stStream;
	VENC_CHN_STATUS_S stStat;
	CVI_RTSP_DATA rtsp_data;
	int frames = 0;
	time_t end_at;
	CVI_S32 s32Ret;

	printf("my_cam_test: waiting %d s for AE/AWB...\n", ISP_SETTLE_SEC);
	for (int i = 0; i < ISP_SETTLE_SEC && !g_stop; i++)
		sleep(1);
	if (g_stop)
		return CVI_FAILURE;

	end_at = time(NULL) + stream_sec;
	printf("my_cam_test: RTSP streaming for %d s (Ctrl+C to stop early)\n",
	       stream_sec);

	while (!g_stop && time(NULL) < end_at) {
		memset(&stStream, 0, sizeof(stStream));
		memset(&stStat, 0, sizeof(stStat));

		s32Ret = CVI_VENC_QueryStatus(VENC_CHN_ID, &stStat);
		if (s32Ret != CVI_SUCCESS || stStat.u32CurPacks == 0) {
			usleep(10000);
			continue;
		}

		stStream.pstPack = calloc(stStat.u32CurPacks, sizeof(VENC_PACK_S));
		if (!stStream.pstPack)
			return CVI_FAILURE;

		s32Ret = CVI_VENC_GetStream(VENC_CHN_ID, &stStream,
					    g_venc_ic.getstream_timeout);
		if (s32Ret != CVI_SUCCESS) {
			free(stStream.pstPack);
			usleep(10000);
			continue;
		}

		memset(&rtsp_data, 0, sizeof(rtsp_data));
		rtsp_data.blockCnt = stStream.u32PackCount;
		for (CVI_U32 i = 0; i < stStream.u32PackCount; i++) {
			VENC_PACK_S *pack = &stStream.pstPack[i];

			rtsp_data.dataPtr[i] = pack->pu8Addr + pack->u32Offset;
			rtsp_data.dataLen[i] = pack->u32Len - pack->u32Offset;
		}

		if (CVI_RTSP_WriteFrame(g_rtsp_ctx, g_rtsp_session->video,
					&rtsp_data) != 0)
			printf("my_cam_test: RTSP_WriteFrame failed (frame %d)\n",
			       frames + 1);

		CVI_VENC_ReleaseStream(VENC_CHN_ID, &stStream);
		free(stStream.pstPack);
		frames++;
	}

	if (frames < RTSP_MIN_FRAMES) {
		printf("my_cam_test: RTSP too few frames (%d)\n", frames);
		return CVI_FAILURE;
	}

	printf("my_cam_test: RTSP streamed %d frames\n", frames);
	return CVI_SUCCESS;
}

static CVI_S32 phase5_run(int stream_sec)
{
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	CVI_S32 s32Ret;

	s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(
		g_stViConfig.astViInfo[0].stSnsInfo.enSnsType, &enPicSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, &stSize);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = vpss_init(&stSize, 0);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = vi_bind_vpss();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = venc_init(enPicSize, 1);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = rtsp_init();
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	return stream_venc_to_rtsp(stream_sec);
}

static void rtsp_deinit(void)
{
	if (!g_rtsp_up)
		return;

	CVI_RTSP_Stop(g_rtsp_ctx);
	CVI_RTSP_DestroySession(g_rtsp_ctx, g_rtsp_session);
	CVI_RTSP_Destroy(&g_rtsp_ctx);
	g_rtsp_session = NULL;
	g_rtsp_ctx = NULL;
	g_rtsp_up = CVI_FALSE;
	printf("my_cam_test: RTSP deinit done\n");
}

static void venc_deinit(void)
{
	if (!g_venc_up)
		return;

	SAMPLE_COMM_VPSS_UnBind_VENC(VPSS_GRP_ID, VPSS_CHN_ID, VENC_CHN_ID);
	SAMPLE_COMM_VENC_Stop(VENC_CHN_ID);
	g_venc_up = CVI_FALSE;
	printf("my_cam_test: VENC deinit done\n");
}

static void vpss_deinit(void)
{
	CVI_BOOL abChnEnable[VPSS_MAX_PHY_CHN_NUM] = {0};
	VI_PIPE vi_pipe;
	VI_CHN vi_chn;
	int cam;

	if (!g_vpss_up)
		return;

	abChnEnable[VPSS_CHN_ID] = CVI_TRUE;
	for (cam = MAX_CAM - 1; cam >= 0; cam--) {
		if (!(g_vpss_grp_mask & (1 << cam)))
			continue;

		vi_pipe = g_stViConfig.astViInfo[cam].stPipeInfo.aPipe[0];
		vi_chn = g_stViConfig.astViInfo[cam].stChnInfo.ViChn;
		SAMPLE_COMM_VI_UnBind_VPSS(vi_pipe, vi_chn, (VPSS_GRP)cam);
		SAMPLE_COMM_VPSS_Stop((VPSS_GRP)cam, abChnEnable);
		printf("my_cam_test: VPSS grp%d deinit done\n", cam);
	}

	g_vpss_grp_mask = 0;
	g_vpss_up = CVI_FALSE;
}

static void vi_deinit(void)
{
	if (g_stViConfig.s32WorkingViNum == 0)
		return;

	rtsp_deinit();
	venc_deinit();
	vpss_deinit();
	SAMPLE_COMM_VI_DestroyIsp(&g_stViConfig); /* 停止 ISP */
	SAMPLE_COMM_VI_DestroyVi(&g_stViConfig);  /* 销毁 VI */
	SAMPLE_COMM_SYS_Exit();                   /* 释放 VB */
	printf("my_cam_test: VI/ISP deinit done\n");
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
	printf("  -p  2, 3, 4, 5, 6, or 7 (default %d)\n", DEFAULT_PHASE);
	printf("  -o  phase 3 default %s; phase 4 default %s\n",
	       DEFAULT_YUV_PATH, DEFAULT_H264_PATH);
	printf("  -s  phase 2/6 hold seconds (default %d); phase 5 stream seconds (default %d)\n",
	       DEFAULT_HOLD_SEC, DEFAULT_STREAM_SEC);
	printf("  -P  RTSP port for phase 5 (default %d)\n", DEFAULT_RTSP_PORT);
	printf("  -u  RTSP URL path for phase 5 (default %s)\n", DEFAULT_RTSP_URL);
	printf("  -v  VI/ISP/VPSS/VENC/VB debug logs\n");
}

int main(int argc, char **argv)
{
	int hold_sec = DEFAULT_HOLD_SEC;
	int stream_sec = DEFAULT_STREAM_SEC;
	int opt;
	CVI_S32 s32Ret;

	for (opt = 1; opt < argc; opt++) {
		if (strcmp(argv[opt], "-h") == 0 || strcmp(argv[opt], "--help") == 0) {
			usage(argv[0]);
			return 0;
		}
		if (strcmp(argv[opt], "-p") == 0 && opt + 1 < argc) {
			g_phase = atoi(argv[++opt]);
			if (g_phase < 2 || g_phase > 7) {
				printf("my_cam_test: invalid phase %d (use 2-7)\n", g_phase);
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
			strncpy(g_out_path, argv[++opt], sizeof(g_out_path) - 1);
			g_out_path[sizeof(g_out_path) - 1] = '\0';
			g_out_path_set = 1;
			continue;
		}
		if (strcmp(argv[opt], "-P") == 0 && opt + 1 < argc) {
			g_rtsp_port = atoi(argv[++opt]);
			if (g_rtsp_port < 1 || g_rtsp_port > 65535) {
				printf("my_cam_test: invalid RTSP port %d\n", g_rtsp_port);
				return 1;
			}
			continue;
		}
		if (strcmp(argv[opt], "-u") == 0 && opt + 1 < argc) {
			strncpy(g_rtsp_url, argv[++opt], sizeof(g_rtsp_url) - 1);
			g_rtsp_url[sizeof(g_rtsp_url) - 1] = '\0';
			continue;
		}
		if (strcmp(argv[opt], "-v") == 0) {
			g_verbose = 1;
			continue;
		}
		usage(argv[0]);
		return 1;
	}

	signal(SIGPIPE, SIG_IGN);       /* RTSP 客户端断开时忽略 SIGPIPE */
	signal(SIGINT, handle_signal);  /* Ctrl+C 触发清理 */
	signal(SIGTERM, handle_signal);

	if (!g_out_path_set) {
		if (g_phase == 4)
			strncpy(g_out_path, DEFAULT_H264_PATH, sizeof(g_out_path) - 1);
		else if (g_phase == 3)
			strncpy(g_out_path, DEFAULT_YUV_PATH, sizeof(g_out_path) - 1);
		g_out_path[sizeof(g_out_path) - 1] = '\0';
	}

	printf("=== EdgeEye my_cam_test (phase %d) ===\n", g_phase);

	s32Ret = vi_init();
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: FAILED init %#x\n", s32Ret);
		return 1;
	}

	if (g_phase == 3) {
		s32Ret = phase3_run();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 3 %#x\n", s32Ret);
			vi_deinit();
			return 1;
		}
	} else if (g_phase == 4) {
		s32Ret = phase4_run();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 4 %#x\n", s32Ret);
			vi_deinit();
			return 1;
		}
	} else if (g_phase == 5) {
		s32Ret = phase5_run(stream_sec);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 5 %#x\n", s32Ret);
			vi_deinit();
			return 1;
		}
	} else if (g_phase == 6) {
		s32Ret = phase6a_validate();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 6 %#x\n", s32Ret);
			vi_deinit();
			return 1;
		}
		printf("holding %d s (dual ISP running)...\n", hold_sec);
		for (int i = 0; i < hold_sec && !g_stop; i++)
			sleep(1);
	} else if (g_phase == 7) {
		s32Ret = phase7_run();
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: FAILED phase 7 %#x\n", s32Ret);
			vi_deinit();
			return 1;
		}
	} else {
		printf("holding %d s (ISP running)...\n", hold_sec);
		for (int i = 0; i < hold_sec && !g_stop; i++)
			sleep(1);
	}

	vi_deinit();
	printf("my_cam_test: PASSED (phase %d)\n", g_phase);
	return 0;
}
