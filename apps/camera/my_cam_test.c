/*
 * my_cam_test.c — EdgeEye 阶段 2：仅初始化 VI/ISP（无 VPSS/VENC/RTSP）
 *
 * 测试接口：读 /mnt/data/sensor_cfg.ini + /mnt/cfg/param/cvi_sdr_bin，拉起 sensor 与 ISP
 * 测试场景：单摄 J1 GC2083 或 J2 OV5647；运行 N 秒后干净退出
 *
 * 板上用法：
 *   ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
 *   ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
 *   ./my_cam_test
 *   ./my_cam_test -s 30
 */

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "sample_comm.h"

static SAMPLE_VI_CONFIG_S g_stViConfig;
static volatile sig_atomic_t g_stop;
static int g_verbose;

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
	const CVI_U32 vb_cnt = 3;

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
				pstVbConf->astCommPool[j].u32BlkCnt += vb_cnt;
				create_new = CVI_FALSE;
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

	s32Ret = setup_vb_pool(&stIniCfg, &stViConfig, &stVbConf);
	if (s32Ret != CVI_SUCCESS)
		return s32Ret;

	s32Ret = SAMPLE_COMM_SYS_Init(&stVbConf); /* 初始化 VB 与系统 */
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: SYS_Init failed %#x\n", s32Ret);
		return s32Ret;
	}

	s32Ret = SAMPLE_PLAT_VI_INIT(&stViConfig); /* 启动 VI + ISP */
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: VI_Init failed %#x\n", s32Ret);
		SAMPLE_COMM_SYS_Exit();
		return s32Ret;
	}

	printf("my_cam_test: VI/ISP init OK (look for sensor Init OK above)\n");
	return CVI_SUCCESS;
}

static void vi_deinit(void)
{
	if (g_stViConfig.s32WorkingViNum == 0)
		return;

	SAMPLE_COMM_VI_DestroyIsp(&g_stViConfig); /* 停止 ISP */
	SAMPLE_COMM_VI_DestroyVi(&g_stViConfig);  /* 销毁 VI */
	SAMPLE_COMM_SYS_Exit();                   /* 释放 VB */
	printf("my_cam_test: VI/ISP deinit done\n");
}

static void usage(const char *prog)
{
	printf("Usage: %s [-s SECONDS] [-v]\n", prog);
	printf("  Phase-2 test: init VI/ISP from sensor_cfg.ini, hold, then exit.\n");
	printf("  -v  VI/ISP/VB debug logs (CVI_DBG_DEBUG)\n");
	printf("  Default hold: 10 seconds. Ctrl+C also exits cleanly.\n");
}

int main(int argc, char **argv)
{
	int hold_sec = 10;
	int opt;
	CVI_S32 s32Ret;

	for (opt = 1; opt < argc; opt++) {
		if (strcmp(argv[opt], "-h") == 0 || strcmp(argv[opt], "--help") == 0) {
			usage(argv[0]);
			return 0;
		}
		if (strcmp(argv[opt], "-s") == 0 && opt + 1 < argc) {
			hold_sec = atoi(argv[++opt]);
			if (hold_sec < 1)
				hold_sec = 1;
			continue;
		}
		if (strcmp(argv[opt], "-v") == 0) {
			g_verbose = 1;
			continue;
		}
		usage(argv[0]);
		return 1;
	}

	signal(SIGINT, handle_signal);  /* Ctrl+C 触发清理 */
	signal(SIGTERM, handle_signal);

	printf("=== EdgeEye my_cam_test (phase 2: VI only) ===\n");

	s32Ret = vi_init();
	if (s32Ret != CVI_SUCCESS) {
		printf("my_cam_test: FAILED init %#x\n", s32Ret);
		return 1;
	}

	printf("holding %d s (ISP running)...\n", hold_sec);
	for (int i = 0; i < hold_sec && !g_stop; i++)
		sleep(1);

	vi_deinit();
	printf("my_cam_test: PASSED\n");
	return 0;
}
