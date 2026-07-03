/*
 * cam_isp_tuning.c — 双摄 per-pipe PQ 加载与 dual_plat_vi_init
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cvi_bin.h"
#include "cam_isp_tuning.h"
#include "cam_pipeline_config.h"

CVI_S32 cam_isp_load_pq_bin(enum CVI_BIN_SECTION_ID isp_id, const char *path)
{
	FILE *fp;
	CVI_U8 *buf;
	CVI_U32 file_size;
	CVI_S32 s32Ret;
	int pipe = (int)isp_id - (int)CVI_BIN_ID_ISP0;

	fp = fopen(path, "rb");
	if (!fp) {
		printf("my_cam_test: PQ open pipe%d %s failed\n", pipe, path);
		return CVI_FAILURE;
	}

	fseek(fp, 0, SEEK_END);
	file_size = (CVI_U32)ftell(fp);
	rewind(fp);
	if (file_size == 0) {
		fclose(fp);
		printf("my_cam_test: PQ empty pipe%d %s\n", pipe, path);
		return CVI_FAILURE;
	}

	buf = malloc(file_size);
	if (!buf) {
		fclose(fp);
		return CVI_FAILURE;
	}
	if (fread(buf, 1, file_size, fp) != file_size) {
		free(buf);
		fclose(fp);
		printf("my_cam_test: PQ read pipe%d %s failed\n", pipe, path);
		return CVI_FAILURE;
	}
	fclose(fp);

	s32Ret = CVI_BIN_LoadParamFromBinEx(isp_id, buf, file_size);
	free(buf);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: PQ load pipe%d <- %s failed %#x\n", pipe, path, s32Ret);
		return s32Ret;
	}

	printf("my_cam_test: PQ loaded pipe%d <- %s\n", pipe, path);
	return CVI_SUCCESS;
}

static CVI_S32 dual_comm_vi_create_isp_with_pq(SAMPLE_VI_CONFIG_S *pstViConfig)
{
	static const char *pq_paths[CAM_MAX_SENSORS] = { CAM_PQ_BIN_GC2083, CAM_PQ_BIN_OV5647 };
	CVI_S32 i, s32ViNum, s32Ret;
	SAMPLE_VI_INFO_S *pstViInfo;
	VI_PIPE ViPipe;

	for (i = 0; i < pstViConfig->s32WorkingViNum; i++) {
		s32ViNum = pstViConfig->as32WorkingViId[i];
		pstViInfo = &pstViConfig->astViInfo[s32ViNum];
		ViPipe = pstViInfo->stPipeInfo.aPipe[0];

		s32Ret = SAMPLE_COMM_VI_StartIsp(pstViInfo);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: StartIsp pipe%d failed %#x\n", ViPipe, s32Ret);
			return s32Ret;
		}

		if (ViPipe < 0 || ViPipe >= CAM_MAX_SENSORS) {
			printf("my_cam_test: bad ViPipe %d for PQ\n", ViPipe);
			return CVI_FAILURE;
		}

		s32Ret = cam_isp_load_pq_bin((enum CVI_BIN_SECTION_ID)(CVI_BIN_ID_ISP0 + ViPipe),
					     pq_paths[ViPipe]);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;
	}

	s32Ret = SAMPLE_COMM_ISP_Run(0);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: ISP_Run(0) failed %#x\n", s32Ret);
		return s32Ret;
	}

	printf("my_cam_test: dual ISP OK (per-pipe PQ, ISP_Run pipe0)\n");
	return CVI_SUCCESS;
}

CVI_S32 cam_isp_dual_plat_vi_init(SAMPLE_VI_CONFIG_S *pstViConfig)
{
	PIC_SIZE_E enPicSize;
	SIZE_S stSize;
	VI_DEV ViDev = 0;
	VI_PIPE ViPipe = 0;
	VI_PIPE_ATTR_S stPipeAttr;
	CVI_S32 s32Ret = CVI_SUCCESS;
	CVI_S32 i, j, s32DevNum;
	SAMPLE_VI_INFO_S *pstViInfo = NULL;
	SAMPLE_SNS_TYPE_E sns_type;

	/* 与 SAMPLE_PLAT_VI_INIT 对齐：须先 StartSensor/MIPI，否则 StartViChn ION 失败 */
	s32Ret = SAMPLE_COMM_VI_StartSensor(pstViConfig);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: StartSensor failed %#x\n", s32Ret);
		return s32Ret;
	}

	for (i = 0; i < pstViConfig->s32WorkingViNum; i++) {
		ViDev = i;
		s32Ret = SAMPLE_COMM_VI_StartDev(&pstViConfig->astViInfo[ViDev]);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: VI_StartDev failed %#x\n", s32Ret);
			goto err_destroy_vi;
		}
	}

	s32Ret = SAMPLE_COMM_VI_StartMIPI(pstViConfig);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: StartMIPI failed %#x\n", s32Ret);
		goto err_destroy_vi;
	}

	s32Ret = SAMPLE_COMM_VI_SensorProbe(pstViConfig);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: SensorProbe failed %#x\n", s32Ret);
		goto err_destroy_vi;
	}

	memset(&stPipeAttr, 0, sizeof(stPipeAttr));
	stPipeAttr.bYuvSkip = CVI_FALSE;
	stPipeAttr.enPixFmt = PIXEL_FORMAT_RGB_BAYER_12BPP;
	stPipeAttr.enBitWidth = DATA_BITWIDTH_12;
	stPipeAttr.stFrameRate.s32SrcFrameRate = -1;
	stPipeAttr.stFrameRate.s32DstFrameRate = -1;
	stPipeAttr.bNrEn = CVI_TRUE;
	stPipeAttr.bYuvBypassPath = CVI_FALSE;

	for (i = 0; i < pstViConfig->s32WorkingViNum; i++) {
		s32DevNum = pstViConfig->as32WorkingViId[i];
		pstViInfo = &pstViConfig->astViInfo[s32DevNum];
		sns_type = pstViInfo->stSnsInfo.enSnsType;

		s32Ret = SAMPLE_COMM_VI_GetSizeBySensor(sns_type, &enPicSize);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: GetSizeBySensor pipe%d failed %#x\n", i, s32Ret);
			goto err_destroy_vi;
		}
		s32Ret = SAMPLE_COMM_SYS_GetPicSize(enPicSize, &stSize);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: GetPicSize pipe%d failed %#x\n", i, s32Ret);
			goto err_destroy_vi;
		}

		stPipeAttr.u32MaxW = stSize.u32Width;
		stPipeAttr.u32MaxH = stSize.u32Height;
		stPipeAttr.enCompressMode = pstViInfo->stChnInfo.enCompressMode;
		stPipeAttr.bYuvBypassPath = SAMPLE_COMM_VI_GetYuvBypassSts(sns_type);

		for (j = 0; j < WDR_MAX_PIPE_NUM; j++) {
			if (pstViInfo->stPipeInfo.aPipe[j] < 0 ||
			    pstViInfo->stPipeInfo.aPipe[j] >= VI_MAX_PIPE_NUM)
				continue;

			ViPipe = pstViInfo->stPipeInfo.aPipe[j];
			s32Ret = CVI_VI_CreatePipe(ViPipe, &stPipeAttr);
			if (s32Ret != CVI_SUCCESS) {
				printf("my_cam_test: CreatePipe %d failed %#x\n", ViPipe, s32Ret);
				goto err_destroy_vi;
			}

			s32Ret = CVI_VI_StartPipe(ViPipe);
			if (s32Ret != CVI_SUCCESS) {
				printf("my_cam_test: StartPipe %d failed %#x\n", ViPipe, s32Ret);
				goto err_destroy_vi;
			}

			s32Ret = CVI_VI_GetPipeAttr(ViPipe, &stPipeAttr);
			if (s32Ret != CVI_SUCCESS) {
				printf("my_cam_test: GetPipeAttr %d failed %#x\n", ViPipe, s32Ret);
				goto err_destroy_vi;
			}
		}
	}

	s32Ret = dual_comm_vi_create_isp_with_pq(pstViConfig);
	if (s32Ret != CVI_SUCCESS) {
		SAMPLE_COMM_VI_DestroyIsp(pstViConfig);
		goto err_destroy_vi;
	}

	s32Ret = SAMPLE_COMM_VI_StartViChn(pstViConfig);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: StartViChn failed %#x\n", s32Ret);
		SAMPLE_COMM_VI_DestroyIsp(pstViConfig);
		goto err_destroy_vi;
	}

	printf("my_cam_test: dual VI/ISP/chn OK (%d sensors)\n",
	       pstViConfig->s32WorkingViNum);
	return CVI_SUCCESS;

err_destroy_vi:
	SAMPLE_COMM_VI_DestroyVi(pstViConfig);
	return s32Ret;
}
