/*
 * cam_vi_bringup.c — VI/SYS 初始化（按 dev_num 自动单摄/双摄）
 */
#include <stdio.h>
#include <string.h>

#include "cvi_isp.h"
#include "cvi_sys.h"
#include "cam_app_context.h"
#include "cam_isp_tuning.h"
#include "cam_pipeline_config.h"
#include "cam_pipeline_mode.h"
#include "cam_rtsp_stream.h"
#include "cam_venc_encode.h"
#include "cam_vpss_capture.h"
#include "cam_vi_bringup.h"

void cam_vi_prepare_dual_online_config(SAMPLE_VI_CONFIG_S *pstViConfig)
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

CVI_S32 cam_vi_setup_dual_media_mode(void)
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

	g_cam_dual_media_mode = CVI_TRUE;
	printf("my_cam_test: dual VI-VPSS online (VPSS_INPUT_MEM+ISP, ViPipe[1]=0)\n");
	return CVI_SUCCESS;
}

static CVI_S32 setup_vb_pool(const SAMPLE_INI_CFG_S *pstIniCfg,
			     SAMPLE_VI_CONFIG_S *pstViConfig,
			     VB_CONFIG_S *pstVbConf)
{
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	CVI_U32 u32BlkSize, u32BlkRotSize;
	CVI_U32 vb_cnt = 3;
	CVI_BOOL dual_vpss = cam_is_dual() && cam_phase_needs_vpss(g_cam_phase);

	if (cam_is_dual() && cam_phase_needs_vpss(g_cam_phase)) {
		vb_cnt = (g_cam_phase >= 4) ? 10 : 8;
	} else if (g_cam_phase >= 4 && g_cam_phase <= 5) {
		vb_cnt = 8;
	} else if (g_cam_phase == 3 || dual_vpss) {
		vb_cnt = 8;
	}

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
				if (!dual_vpss) {
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

CVI_S32 cam_vi_bringup_init(void)
{
	MMF_VERSION_S stVersion;
	SAMPLE_INI_CFG_S stIniCfg;
	SAMPLE_VI_CONFIG_S stViConfig;
	VB_CONFIG_S stVbConf;
	LOG_LEVEL_CONF_S log_conf;
	CVI_S32 s32Ret;

	CVI_SYS_GetVersion(&stVersion);
	printf("MMF Version: %s\n", stVersion.version);

	log_conf.enModId = CVI_ID_LOG;
	log_conf.s32Level = g_cam_verbose ? CVI_DBG_DEBUG : CVI_DBG_INFO;
	CVI_LOG_SetLevelConf(&log_conf);
	if (g_cam_verbose)
		log_set_verbose();

	s32Ret = SAMPLE_COMM_VI_ParseIni(&stIniCfg);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: ParseIni failed (check /mnt/data/sensor_cfg.ini)\n");
		return s32Ret;
	}

	g_cam_dev_num = stIniCfg.devNum;
	printf("sensor_cfg.ini: dev_num=%u (%s)\n", g_cam_dev_num,
	       cam_is_dual() ? "dual" : "single");

	CVI_VI_SetDevNum(stIniCfg.devNum);

	s32Ret = SAMPLE_COMM_VI_IniToViCfg(&stIniCfg, &stViConfig);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	if (cam_is_dual() && cam_phase_needs_vpss(g_cam_phase))
		cam_vi_prepare_dual_online_config(&stViConfig);

	memcpy(&g_cam_vi_cfg, &stViConfig, sizeof(g_cam_vi_cfg));

	s32Ret = setup_vb_pool(&stIniCfg, &stViConfig, &stVbConf);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_Init(&stVbConf);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: SYS_Init failed %#x\n", s32Ret);
		return s32Ret;
	}

	if (cam_is_dual() && cam_phase_needs_vpss(g_cam_phase)) {
		s32Ret = cam_vi_setup_dual_media_mode();
		if (s32Ret != CVI_SUCCESS) {
			SAMPLE_COMM_SYS_Exit();
			return s32Ret;
		}
	}

	if (cam_is_dual())
		s32Ret = cam_isp_dual_plat_vi_init(&stViConfig);
	else
		s32Ret = SAMPLE_PLAT_VI_INIT(&stViConfig);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VI_Init failed %#x\n", s32Ret);
		SAMPLE_COMM_SYS_Exit();
		return s32Ret;
	}

	if (cam_is_dual()) {
		for (CVI_S32 i = 0; i < stViConfig.s32WorkingViNum; i++) {
			ISP_PUB_ATTR_S stPubAttr = {0};
			VI_PIPE pipe = stViConfig.astViInfo[i].stPipeInfo.aPipe[0];

			CVI_ISP_GetPubAttr(pipe, &stPubAttr);
			printf("my_cam_test: pipe%d ISP FPS %.2f\n", pipe, stPubAttr.f32FrameRate);
		}
	}

	printf("my_cam_test: VI/ISP init OK (%s, %d sensor(s))\n",
	       cam_is_dual() ? "dual" : "single", cam_sensor_count());
	return CVI_SUCCESS;
}

void cam_vi_bringup_deinit(void)
{
	if (g_cam_vi_cfg.s32WorkingViNum == 0)
		return;

	cam_rtsp_teardown();
	cam_venc_teardown();
	cam_vpss_teardown();
	SAMPLE_COMM_VI_DestroyIsp(&g_cam_vi_cfg);
	SAMPLE_COMM_VI_DestroyVi(&g_cam_vi_cfg);
	SAMPLE_COMM_SYS_Exit();
	printf("my_cam_test: VI/ISP deinit done\n");
}
