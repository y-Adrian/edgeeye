/*
 * cam_venc_encode.c — H.264 VENC 初始化与 elementary stream 写盘
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "cvi_venc.h"
#include "cam_app_context.h"
#include "cam_pipeline_config.h"
#include "cam_venc_encode.h"
#include "cam_vpss_capture.h"

static void venc_fill_h264_cbr_defaults(chnInputCfg *pIc, int continuous)
{
	SAMPLE_COMM_VENC_InitChnInputCfg(pIc);
	strcpy(pIc->codec, "264");
	pIc->bind_mode = VENC_BIND_VPSS;
	pIc->vpssGrp = CAM_VPSS_GRP_ID;
	pIc->vpssChn = CAM_VPSS_CHN_ID;
	pIc->num_frames = continuous ? -1 : 90;
	pIc->getstream_timeout = CAM_FRAME_WAIT_MS;
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

static CVI_BOOL venc_stream_has_h264_idr(const VENC_STREAM_S *pstStream)
{
	for (CVI_U32 i = 0; i < pstStream->u32PackCount; i++) {
		H264E_NALU_TYPE_E nalu = pstStream->pstPack[i].DataType.enH264EType;

		if (nalu == H264E_NALU_IDRSLICE || nalu == H264E_NALU_ISLICE)
			return CVI_TRUE;
	}
	return CVI_FALSE;
}

static CVI_S32 venc_fetch_stream(VENC_CHN venc_chn, VENC_STREAM_S *pstStream,
				 int timeout_ms)
{
	VENC_CHN_STATUS_S stStat;
	CVI_S32 s32Ret;

	memset(pstStream, 0, sizeof(*pstStream));
	memset(&stStat, 0, sizeof(stStat));

	s32Ret = CVI_VENC_QueryStatus(venc_chn, &stStat);
	if (s32Ret != CVI_SUCCESS || stStat.u32CurPacks == 0)
		return CVI_FAILURE;

	pstStream->pstPack = calloc(stStat.u32CurPacks, sizeof(VENC_PACK_S));
	if (!pstStream->pstPack)
		return CVI_FAILURE;

	s32Ret = CVI_VENC_GetStream(venc_chn, pstStream, timeout_ms);
	if (s32Ret != CVI_SUCCESS) {
		free(pstStream->pstPack);
		pstStream->pstPack = NULL;
	}
	return s32Ret;
}

static void venc_release_stream(VENC_CHN venc_chn, VENC_STREAM_S *pstStream)
{
	if (!pstStream->pstPack)
		return;
	CVI_VENC_ReleaseStream(venc_chn, pstStream);
	free(pstStream->pstPack);
	pstStream->pstPack = NULL;
}

CVI_S32 cam_venc_init_chn(VENC_CHN venc_chn, PIC_SIZE_E enPicSize, VPSS_GRP vpss_grp,
			  int continuous)
{
	chnInputCfg ic;
	VENC_GOP_ATTR_S stGop;
	CVI_S32 s32Ret;

	venc_fill_h264_cbr_defaults(&ic, continuous);
	ic.vpssGrp = vpss_grp;

	s32Ret = SAMPLE_COMM_VENC_GetGopAttr(VENC_GOPMODE_NORMALP, &stGop);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VENC_GetGopAttr failed %#x\n", s32Ret);
		return s32Ret;
	}

	s32Ret = SAMPLE_COMM_VENC_Start(&ic, venc_chn, PT_H264, enPicSize,
					SAMPLE_RC_CBR, CVI_H264_PROFILE_DEFAULT,
					CVI_FALSE, &stGop);
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VENC_Start chn%d failed %#x\n", venc_chn, s32Ret);
		return s32Ret;
	}

	if (venc_chn == CAM_VENC_CHN_ID)
		memcpy(&g_cam_venc_ic, &ic, sizeof(g_cam_venc_ic));
	g_cam_venc_stream_timeout[venc_chn] = ic.getstream_timeout;
	g_cam_venc_mask |= (1 << venc_chn);
	g_cam_venc_up = CVI_TRUE;
	printf("my_cam_test: VENC chn%d H264 ready (grp%d pic_size=%d)\n",
	       venc_chn, vpss_grp, enPicSize);
	return CVI_SUCCESS;
}

CVI_S32 cam_venc_init_single(PIC_SIZE_E enPicSize, int continuous)
{
	return cam_venc_init_chn(CAM_VENC_CHN_ID, enPicSize, CAM_VPSS_GRP_ID, continuous);
}

CVI_S32 cam_venc_capture_chn(VENC_CHN venc_chn, const char *path, CVI_BOOL do_settle,
			     CVI_BOOL save_from_idr)
{
	FILE *fp;
	VENC_STREAM_S stStream;
	size_t total_bytes = 0;
	int streams = 0;
	CVI_S32 s32Ret;
	int timeout_ms = g_cam_venc_stream_timeout[venc_chn];
	CVI_BOOL saving = save_from_idr ? CVI_FALSE : CVI_TRUE;

	if (timeout_ms <= 0)
		timeout_ms = CAM_FRAME_WAIT_MS;

	fp = fopen(path, "wb");
	if (!fp) {
		printf("my_cam_test: fopen(%s) failed\n", path);
		return CVI_FAILURE;
	}

	if (do_settle) {
		printf("my_cam_test: waiting %d s for AE/AWB...\n", CAM_ISP_SETTLE_SEC);
		for (int i = 0; i < CAM_ISP_SETTLE_SEC && !g_cam_stop; i++)
			sleep(1);
		if (g_cam_stop) {
			fclose(fp);
			return CVI_FAILURE;
		}
	}

	for (int attempt = 0; streams < CAM_VENC_SAVE_TARGET_STREAMS &&
	     attempt < CAM_VENC_SAVE_MAX_ATTEMPTS && !g_cam_stop; attempt++) {
		s32Ret = venc_fetch_stream(venc_chn, &stStream, timeout_ms);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: chn%d GetStream attempt %d failed %#x\n",
			       venc_chn, attempt + 1, s32Ret);
			usleep(100000);
			continue;
		}

		if (!saving) {
			if (!venc_stream_has_h264_idr(&stStream)) {
				venc_release_stream(venc_chn, &stStream);
				continue;
			}
			saving = CVI_TRUE;
			printf("my_cam_test: chn%d start save from IDR/I slice\n", venc_chn);
		}

		for (CVI_U32 i = 0; i < stStream.u32PackCount; i++) {
			VENC_PACK_S *pack = &stStream.pstPack[i];

			total_bytes += pack->u32Len - pack->u32Offset;
		}

		s32Ret = SAMPLE_COMM_VENC_SaveStream(PT_H264, fp, &stStream);
		venc_release_stream(venc_chn, &stStream);
		if (s32Ret != CVI_SUCCESS) {
			printf("my_cam_test: chn%d SaveStream failed %#x\n", venc_chn, s32Ret);
			fclose(fp);
			return s32Ret;
		}

		streams++;
	}

	fclose(fp);

	if (!saving || streams == 0 || total_bytes < 1024) {
		printf("my_cam_test: chn%d H264 too small (idr=%d streams=%d bytes=%zu)\n",
		       venc_chn, saving, streams, total_bytes);
		return CVI_FAILURE;
	}

	printf("my_cam_test: saved H264 chn%d -> %s (%zu bytes, %d streams)\n",
	       venc_chn, path, total_bytes, streams);
	return CVI_SUCCESS;
}

CVI_S32 cam_venc_capture_single(const char *path)
{
	return cam_venc_capture_chn(CAM_VENC_CHN_ID, path, CVI_TRUE, CVI_FALSE);
}

void cam_venc_teardown(void)
{
	int cam;

	if (!g_cam_venc_up)
		return;

	for (cam = 0; cam < CAM_MAX_SENSORS; cam++) {
		if (!(g_cam_venc_mask & (1 << cam)))
			continue;
		CVI_VENC_StopRecvFrame((VENC_CHN)cam);
	}

	for (cam = CAM_MAX_SENSORS - 1; cam >= 0; cam--) {
		if (!(g_cam_venc_mask & (1 << cam)))
			continue;

		SAMPLE_COMM_VPSS_UnBind_VENC(cam_vpss_dual_grp(cam), CAM_VPSS_CHN_ID, (VENC_CHN)cam);
		SAMPLE_COMM_VENC_Stop((VENC_CHN)cam);
		printf("my_cam_test: VENC chn%d deinit done\n", cam);
	}

	g_cam_venc_mask = 0;
	g_cam_venc_up = CVI_FALSE;
}
