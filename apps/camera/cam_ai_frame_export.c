/*
 * cam_ai_frame_export.c — 后台响应 AI 取帧请求，直接复用 VPSS 帧
 */
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

#include "cam_ai_frame_export.h"
#include "cam_app_context.h"
#include "cam_log.h"
#include "cam_output_res.h"
#include "cam_pipeline_config.h"
#include "cam_vpss_capture.h"

#define CAM_AI_FRAME_RAW_TMP  "/tmp/edgeeye_ai_frame.nv12.tmp"
#define CAM_AI_FRAME_META_TMP "/tmp/edgeeye_ai_frame.meta.tmp"

static pthread_t g_ai_export_thread;
static CVI_BOOL g_ai_export_running;
static volatile sig_atomic_t g_ai_export_stop;

static CVI_S32 write_frame_meta(const SIZE_S *size)
{
	FILE *fp;

	/* fopen：创建临时元数据，避免读取到半行尺寸。 */
	fp = fopen(CAM_AI_FRAME_META_TMP, "w");
	if (!fp) {
		CAM_LOG("AI frame fopen meta failed\n");
		return CVI_FAILURE;
	}
	/* fprintf：记录 NV12 的紧凑宽高，供 ai_grab_frame 解释 rawvideo。 */
	if (fprintf(fp, "%u %u\n", size->u32Width, size->u32Height) < 0) {
		/* fclose：关闭失败写入的元数据文件。 */
		fclose(fp);
		return CVI_FAILURE;
	}
	/* fclose：刷新并关闭完整元数据。 */
	if (fclose(fp) != 0)
		return CVI_FAILURE;
	/* rename：原子发布元数据文件。 */
	if (rename(CAM_AI_FRAME_META_TMP, CAM_AI_FRAME_META_PATH) != 0)
		return CVI_FAILURE;
	return CVI_SUCCESS;
}

static CVI_S32 export_one_frame(void)
{
	SIZE_S size;
	CVI_S32 ret;

	/* cam_output_res_to_size：取得当前 VPSS/RTSP 输出尺寸。 */
	ret = cam_output_res_to_size(cam_output_res_get(), &size);
	if (ret != CVI_SUCCESS)
		return ret;

	/* cam_vpss_capture_grp_once：短暂持有 ch0 帧并写入临时 NV12。 */
	ret = cam_vpss_capture_grp_once(CAM_VPSS_GRP_ID, CAM_VPSS_CHN_ID,
					CAM_AI_FRAME_RAW_TMP, 1000);
	if (ret != CVI_SUCCESS)
		return ret;

	/* rename：完整写入后再原子发布 NV12。 */
	if (rename(CAM_AI_FRAME_RAW_TMP, CAM_AI_FRAME_RAW_PATH) != 0)
		return CVI_FAILURE;
	ret = write_frame_meta(&size);
	if (ret != CVI_SUCCESS)
		return ret;

	CAM_LOG("AI direct frame ready %ux%u -> %s\n",
		size.u32Width, size.u32Height, CAM_AI_FRAME_RAW_PATH);
	return CVI_SUCCESS;
}

static void *ai_export_thread(void *arg)
{
	(void)arg;

	while (!g_ai_export_stop && !g_cam_stop) {
		/* access：仅在 ai_grab_frame 创建请求文件后抓一帧。 */
		if (access(CAM_AI_FRAME_REQUEST_PATH, F_OK) == 0) {
			if (export_one_frame() != CVI_SUCCESS)
				CAM_LOG("AI direct frame export failed\n");
			/* unlink：无论成功失败都消费本次请求，调用方可重试。 */
			unlink(CAM_AI_FRAME_REQUEST_PATH);
		}
		/* usleep：低频轮询请求，避免占用 C906。 */
		usleep(50000);
	}
	return NULL;
}

CVI_S32 cam_ai_frame_export_start(void)
{
	int ret;

	if (g_ai_export_running)
		return CVI_SUCCESS;

	g_ai_export_stop = 0;
	/* unlink：启动时清理上次异常退出留下的请求和临时文件。 */
	unlink(CAM_AI_FRAME_REQUEST_PATH);
	unlink(CAM_AI_FRAME_RAW_TMP);
	unlink(CAM_AI_FRAME_META_TMP);

	/* pthread_create：后台响应取帧，不阻塞 VENC/RTSP 码流循环。 */
	ret = pthread_create(&g_ai_export_thread, NULL, ai_export_thread, NULL);
	if (ret != 0) {
		CAM_LOG("AI frame export pthread_create failed %d\n", ret);
		return CVI_FAILURE;
	}
	g_ai_export_running = CVI_TRUE;
	CAM_LOG("AI direct frame exporter ready request=%s\n",
		CAM_AI_FRAME_REQUEST_PATH);
	return CVI_SUCCESS;
}

void cam_ai_frame_export_stop(void)
{
	if (!g_ai_export_running)
		return;

	g_ai_export_stop = 1;
	/* pthread_join：等待导出线程释放可能持有的 VPSS 帧。 */
	pthread_join(g_ai_export_thread, NULL);
	g_ai_export_running = CVI_FALSE;
	/* unlink：停止时清理未消费的请求。 */
	unlink(CAM_AI_FRAME_REQUEST_PATH);
}
