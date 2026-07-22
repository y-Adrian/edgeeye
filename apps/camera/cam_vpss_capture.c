/*
 * cam_vpss_capture.c — VPSS 初始化、绑定与 NV12 帧保存
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "cvi_sys.h"
#include "cam_app_context.h"
#include "cam_log.h"
#include "cam_output_res.h"
#include "cam_pipeline_config.h"
#include "cam_vpss_capture.h"

CVI_S32 cam_vpss_init_grp(VPSS_GRP vpss_grp, const SIZE_S *pstSrcSize,
			  const SIZE_S *pstOutSize, CVI_U32 depth, CVI_U8 vpss_dev)
{
	VPSS_GRP_ATTR_S stVpssGrpAttr;
	VPSS_CHN_ATTR_S astVpssChnAttr[VPSS_MAX_PHY_CHN_NUM];
	CVI_BOOL abChnEnable[VPSS_MAX_PHY_CHN_NUM] = {0};
	SIZE_S stOut;
	CVI_S32 s32Ret;

	if (!pstOutSize)
		pstOutSize = pstSrcSize;
	stOut = *pstOutSize;

	memset(&stVpssGrpAttr, 0, sizeof(stVpssGrpAttr));
	memset(astVpssChnAttr, 0, sizeof(astVpssChnAttr));

	stVpssGrpAttr.stFrameRate.s32SrcFrameRate = -1;
	stVpssGrpAttr.stFrameRate.s32DstFrameRate = -1;
	stVpssGrpAttr.enPixelFormat = SAMPLE_PIXEL_FORMAT;
	stVpssGrpAttr.u32MaxW = pstSrcSize->u32Width;
	stVpssGrpAttr.u32MaxH = pstSrcSize->u32Height;
	stVpssGrpAttr.u8VpssDev = vpss_dev;

	astVpssChnAttr[CAM_VPSS_CHN_ID].u32Width = stOut.u32Width;
	astVpssChnAttr[CAM_VPSS_CHN_ID].u32Height = stOut.u32Height;
	astVpssChnAttr[CAM_VPSS_CHN_ID].enVideoFormat = VIDEO_FORMAT_LINEAR;
	astVpssChnAttr[CAM_VPSS_CHN_ID].enPixelFormat = SAMPLE_PIXEL_FORMAT;
	astVpssChnAttr[CAM_VPSS_CHN_ID].stFrameRate.s32SrcFrameRate = -1;
	astVpssChnAttr[CAM_VPSS_CHN_ID].stFrameRate.s32DstFrameRate = -1;
	astVpssChnAttr[CAM_VPSS_CHN_ID].u32Depth = depth;
	astVpssChnAttr[CAM_VPSS_CHN_ID].bMirror = CVI_FALSE;
	astVpssChnAttr[CAM_VPSS_CHN_ID].bFlip = CVI_FALSE;
	astVpssChnAttr[CAM_VPSS_CHN_ID].stAspectRatio.enMode = ASPECT_RATIO_NONE;
	astVpssChnAttr[CAM_VPSS_CHN_ID].stNormalize.bEnable = CVI_FALSE;

	abChnEnable[CAM_VPSS_CHN_ID] = CVI_TRUE;
	if (g_cam_ai_direct && vpss_grp == CAM_VPSS_GRP_ID) {
		/*
		 * CHN1 专供 AI：硬件缩放到模型尺寸并保留一帧深度。
		 * CHN0 继续只绑定 VENC，避免 GetChnFrame 干扰编码队列。
		 */
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].u32Width = CAM_AI_FRAME_WIDTH;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].u32Height = CAM_AI_FRAME_HEIGHT;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].enVideoFormat = VIDEO_FORMAT_LINEAR;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].enPixelFormat = SAMPLE_PIXEL_FORMAT;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].stFrameRate.s32SrcFrameRate = -1;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].stFrameRate.s32DstFrameRate = -1;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].u32Depth = 1;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].bMirror = CVI_FALSE;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].bFlip = CVI_FALSE;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].stAspectRatio.enMode = ASPECT_RATIO_NONE;
		astVpssChnAttr[CAM_VPSS_AI_CHN_ID].stNormalize.bEnable = CVI_FALSE;
		abChnEnable[CAM_VPSS_AI_CHN_ID] = CVI_TRUE;
	}

	s32Ret = SAMPLE_COMM_VPSS_Init(vpss_grp, abChnEnable, &stVpssGrpAttr, astVpssChnAttr);
	if (s32Ret != CVI_SUCCESS) {
		CAM_LOG("VPSS_Init grp%d failed %#x\n", vpss_grp, s32Ret);
		return s32Ret;
	}

	s32Ret = SAMPLE_COMM_VPSS_Start(vpss_grp, abChnEnable, &stVpssGrpAttr, astVpssChnAttr);
	if (s32Ret != CVI_SUCCESS) {
		CAM_LOG("VPSS_Start grp%d failed %#x\n", vpss_grp, s32Ret);
		return s32Ret;
	}

	if (g_cam_dual_media_mode) {
		s32Ret = CVI_VPSS_SetGrpParamfromBin(vpss_grp, CAM_VPSS_CHN_ID);
		if (s32Ret != CVI_SUCCESS)
			CAM_LOG("SetGrpParamfromBin grp%d %#x (non-fatal)\n",
			       vpss_grp, s32Ret);
	}

	g_cam_vpss_grp_mask |= (1 << vpss_grp);
	g_cam_vpss_up = CVI_TRUE;
	if (stOut.u32Width != pstSrcSize->u32Width ||
	    stOut.u32Height != pstSrcSize->u32Height)
		CAM_LOG("VPSS grp%d %ux%u -> %ux%u ready\n", vpss_grp,
		       pstSrcSize->u32Width, pstSrcSize->u32Height,
		       stOut.u32Width, stOut.u32Height);
	else
		CAM_LOG("VPSS grp%d %ux%u ready\n", vpss_grp,
		       stOut.u32Width, stOut.u32Height);
	if (g_cam_ai_direct && vpss_grp == CAM_VPSS_GRP_ID)
		CAM_LOG("VPSS grp%d chn%d AI %dx%d depth=1 ready\n",
		       vpss_grp, CAM_VPSS_AI_CHN_ID,
		       CAM_AI_FRAME_WIDTH, CAM_AI_FRAME_HEIGHT);
	return CVI_SUCCESS;
}

CVI_S32 cam_vpss_init_single(const SIZE_S *pstSrcSize, const SIZE_S *pstOutSize,
			     CVI_U32 depth)
{
	return cam_vpss_init_grp(CAM_VPSS_GRP_ID, pstSrcSize, pstOutSize, depth, 0);
}

CVI_S32 cam_vpss_bind_cam(int cam_idx)
{
	VI_PIPE vi_pipe = g_cam_vi_cfg.astViInfo[cam_idx].stPipeInfo.aPipe[0];
	VI_CHN vi_chn = g_cam_vi_cfg.astViInfo[cam_idx].stChnInfo.ViChn;
	VPSS_GRP vpss_grp = (VPSS_GRP)cam_idx;
	CVI_S32 s32Ret;

	s32Ret = SAMPLE_COMM_VI_Bind_VPSS(vi_pipe, vi_chn, vpss_grp);
	if (s32Ret != CVI_SUCCESS) {
		CAM_LOG("VI_Bind_VPSS cam%d failed %#x (pipe=%d chn=%d)\n",
		       cam_idx, s32Ret, vi_pipe, vi_chn);
		return s32Ret;
	}

	CAM_LOG("cam%d VI pipe %d chn %d -> VPSS grp %d\n",
	       cam_idx, vi_pipe, vi_chn, vpss_grp);
	return CVI_SUCCESS;
}

CVI_S32 cam_vpss_bind_single(void)
{
	return cam_vpss_bind_cam(0);
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
		CAM_LOG("fopen(%s) failed\n", path);
		return CVI_FAILURE;
	}

	u32_luma = pstFrame->stVFrame.u32Stride[0] * pstFrame->stVFrame.u32Height;
	u32_chroma = pstFrame->stVFrame.u32Stride[1] * pstFrame->stVFrame.u32Height / 2;

	vir_addr = CVI_SYS_Mmap(pstFrame->stVFrame.u64PhyAddr[0], image_size);
	if (!vir_addr) {
		fclose(fp);
		CAM_LOG("Mmap frame failed\n");
		return CVI_FAILURE;
	}

	CVI_SYS_IonInvalidateCache(pstFrame->stVFrame.u64PhyAddr[0], vir_addr, image_size);

	{
		CVI_U8 *y = (CVI_U8 *)vir_addr;
		CVI_U64 sum = 0;
		CVI_U32 y_pixels = pstFrame->stVFrame.u32Width * pstFrame->stVFrame.u32Height;

		for (CVI_U32 n = 0; n < y_pixels; n += 64)
			sum += y[n];
		CAM_LOG("frame Y mean(sampled)=%llu (0=black 128=gray 255=white)\n",
		       (unsigned long long)(sum / (y_pixels / 64 + 1)));
	}

	plane_offset = 0;
	for (int i = 0; i < 3; i++) {
		if (pstFrame->stVFrame.u32Length[i] == 0)
			continue;

		CVI_U8 *plane = (CVI_U8 *)vir_addr + plane_offset;
		size_t write_len = (i == 0) ? u32_luma : u32_chroma;

		if (fwrite(plane, write_len, 1, fp) != 1) {
			CVI_SYS_Munmap(vir_addr, image_size);
			fclose(fp);
			CAM_LOG("fwrite plane %d failed\n", i);
			return CVI_FAILURE;
		}
		plane_offset += pstFrame->stVFrame.u32Length[i];
	}

	CVI_SYS_Munmap(vir_addr, image_size);
	fclose(fp);

	CAM_LOG("saved %ux%u NV12 -> %s (%zu bytes payload)\n",
	       pstFrame->stVFrame.u32Width, pstFrame->stVFrame.u32Height,
	       path, image_size);
	return CVI_SUCCESS;
}

CVI_S32 cam_vpss_capture_grp_once(VPSS_GRP vpss_grp, VPSS_CHN vpss_chn,
				   const char *path, CVI_S32 timeout_ms)
{
	VIDEO_FRAME_INFO_S stFrame;
	CVI_S32 s32Ret;

	/* memset：清空帧描述，避免失败路径读取未初始化字段。 */
	memset(&stFrame, 0, sizeof(stFrame));
	/* CVI_VPSS_GetChnFrame：从已启用深度的 VPSS 通道取得一帧。 */
	s32Ret = CVI_VPSS_GetChnFrame(vpss_grp, vpss_chn, &stFrame, timeout_ms);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = save_nv12_frame(&stFrame, path);
	/* CVI_VPSS_ReleaseChnFrame：尽快归还 VB，避免阻塞 VENC。 */
	if (CVI_VPSS_ReleaseChnFrame(vpss_grp, vpss_chn, &stFrame) != CVI_SUCCESS) {
		CAM_LOG("grp%d chn%d ReleaseChnFrame failed\n", vpss_grp, vpss_chn);
		if (s32Ret == CVI_SUCCESS)
			s32Ret = CVI_FAILURE;
	}
	return s32Ret;
}

CVI_S32 cam_vpss_capture_grp(VPSS_GRP vpss_grp, const char *path, CVI_BOOL do_settle)
{
	VIDEO_FRAME_INFO_S stFrame;
	CVI_S32 s32Ret;
	int attempt;

	memset(&stFrame, 0, sizeof(stFrame));

	if (do_settle) {
		CAM_LOG("waiting %d s for AE/AWB...\n", CAM_ISP_SETTLE_SEC);
		for (int i = 0; i < CAM_ISP_SETTLE_SEC && !g_cam_stop; i++)
			sleep(1);
		if (g_cam_stop)
			return CVI_FAILURE;
	}

	for (attempt = 1; attempt <= 10; attempt++) {
		/* CVI_VPSS_GetChnFrame：测试模式下重试等待 VPSS 帧。 */
		s32Ret = CVI_VPSS_GetChnFrame(vpss_grp, CAM_VPSS_CHN_ID, &stFrame, CAM_FRAME_WAIT_MS);
		if (s32Ret == CVI_SUCCESS)
			break;
		CAM_LOG("grp%d GetChnFrame attempt %d failed %#x\n",
		       vpss_grp, attempt, s32Ret);
	}

	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = save_nv12_frame(&stFrame, path);
	/* CVI_VPSS_ReleaseChnFrame：保存后归还测试帧。 */
	if (CVI_VPSS_ReleaseChnFrame(vpss_grp, CAM_VPSS_CHN_ID, &stFrame) != CVI_SUCCESS)
		CAM_LOG("grp%d ReleaseChnFrame failed\n", vpss_grp);

	return s32Ret;
}

CVI_S32 cam_vpss_capture_single(const char *path)
{
	return cam_vpss_capture_grp(CAM_VPSS_GRP_ID, path, CVI_TRUE);
}

VPSS_GRP cam_vpss_dual_grp(int cam)
{
	if (g_cam_dual_media_mode)
		return cam == 0 ? VPSS_ONLINE_GRP_0 : VPSS_ONLINE_GRP_1;
	return (VPSS_GRP)cam;
}

CVI_S32 cam_vpss_init_dual(CVI_U32 depth)
{
	SIZE_S stSrc, stOut;
	CVI_S32 s32Ret;
	int cam;

	for (cam = 0; cam < g_cam_vi_cfg.s32WorkingViNum; cam++) {
		VPSS_GRP vpss_grp = cam_vpss_dual_grp(cam);
		CVI_U8 vpss_dev = g_cam_dual_media_mode ? 1 : 0;

		s32Ret = cam_sensor_size_by_cam(cam, &stSrc, NULL);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;

		cam_output_res_effective(&stSrc, &stOut, NULL);

		s32Ret = cam_vpss_init_grp(vpss_grp, &stSrc, &stOut, depth, vpss_dev);
		if (s32Ret != CVI_SUCCESS)
			return s32Ret;

		if (!g_cam_dual_media_mode) {
			s32Ret = cam_vpss_bind_cam(cam);
			if (s32Ret != CVI_SUCCESS)
				return s32Ret;
		} else if (cam == 0) {
			s32Ret = cam_vpss_bind_cam(cam);
			if (s32Ret != CVI_SUCCESS)
				return s32Ret;
			CAM_LOG("cam0 grp0 online u8VpssDev=1 + VI bind\n");
		} else {
			CAM_LOG("cam1 grp1 online u8VpssDev=1 (no VI bind)\n");
		}
	}

	return CVI_SUCCESS;
}

void cam_vpss_teardown(void)
{
	CVI_BOOL abChnEnable[VPSS_MAX_PHY_CHN_NUM] = {0};
	VI_PIPE vi_pipe;
	VI_CHN vi_chn;
	int cam;

	if (!g_cam_vpss_up)
		return;

	abChnEnable[CAM_VPSS_CHN_ID] = CVI_TRUE;
	if (g_cam_ai_direct)
		abChnEnable[CAM_VPSS_AI_CHN_ID] = CVI_TRUE;
	for (cam = CAM_MAX_SENSORS - 1; cam >= 0; cam--) {
		if (!(g_cam_vpss_grp_mask & (1 << cam)))
			continue;

		vi_pipe = g_cam_vi_cfg.astViInfo[cam].stPipeInfo.aPipe[0];
		vi_chn = g_cam_vi_cfg.astViInfo[cam].stChnInfo.ViChn;
		SAMPLE_COMM_VI_UnBind_VPSS(vi_pipe, vi_chn, (VPSS_GRP)cam);
		SAMPLE_COMM_VPSS_Stop((VPSS_GRP)cam, abChnEnable);
		CAM_LOG("VPSS grp%d deinit done\n", cam);
	}

	g_cam_vpss_grp_mask = 0;
	g_cam_vpss_up = CVI_FALSE;
}
