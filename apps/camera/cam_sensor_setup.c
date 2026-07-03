/*
 * cam_sensor_setup.c — 按模式链 sensor_cfg.ini（与 scripts/my_cam_test_common.sh 一致）
 */
#include <stdio.h>
#include <unistd.h>

#include "cam_log.h"
#include "cam_sensor_setup.h"

#define SENSOR_CFG_LINK   "/mnt/data/sensor_cfg.ini"
#define INI_GC2083        "/mnt/data/sensor_cfg_GC2083.ini"
#define INI_OV5647        "/mnt/data/sensor_cfg_OV5647_J2.ini"
#define INI_DUAL          "/mnt/data/sensor_cfg_GC2083_OV5647_dual.ini"
#define INI_DUAL_FALLBACK "/root/stream/sensor_cfg_GC2083_OV5647_dual.ini"

#define PQ_LINK "/mnt/cfg/param/cvi_sdr_bin"

static CVI_S32 link_file(const char *linkpath, const char *target)
{
	if (access(target, F_OK) != 0) {
		CAM_LOG("missing %s\n", target);
		return CVI_FAILURE;
	}
	unlink(linkpath); /* unlink(2)：先删旧链再建 */
	if (symlink(target, linkpath) != 0) {
		CAM_LOG("symlink %s -> %s failed\n", linkpath, target);
		return CVI_FAILURE;
	}
	CAM_LOG("%s -> %s\n", linkpath, target);
	return CVI_SUCCESS;
}

static CVI_S32 check_dual_pq_bins(void)
{
	if (access("/mnt/cfg/param/cvi_sdr_bin_GC2083", F_OK) != 0 &&
	    access("/mnt/cfg/param/cvi_sdr_bin_GC2083", R_OK) != 0) {
		CAM_LOG("missing /mnt/cfg/param/cvi_sdr_bin_GC2083\n");
		return CVI_FAILURE;
	}
	if (access("/mnt/cfg/param/cvi_sdr_bin_OV5647.bin", F_OK) != 0 &&
	    access("/mnt/cfg/param/cvi_sdr_bin_OV5647.bin", R_OK) != 0) {
		CAM_LOG("missing /mnt/cfg/param/cvi_sdr_bin_OV5647.bin\n");
		return CVI_FAILURE;
	}
	return CVI_SUCCESS;
}

CVI_S32 cam_sensor_setup(cam_layout_e layout, cam_sensor_id_e single_sensor)
{
	const char *ini;

	if (layout == CAM_LAYOUT_DUAL) {
		ini = INI_DUAL;
		if (access(ini, F_OK) != 0)
			ini = INI_DUAL_FALLBACK;
		if (link_file(SENSOR_CFG_LINK, ini) != CVI_SUCCESS)
			return CVI_FAILURE;
		return check_dual_pq_bins();
	}

	if (single_sensor == CAM_SENSOR_OV5647) {
		ini = INI_OV5647;
		if (link_file(PQ_LINK, "/mnt/cfg/param/cvi_sdr_bin_OV5647.bin") != CVI_SUCCESS)
			return CVI_FAILURE;
	} else {
		ini = INI_GC2083;
		if (link_file(PQ_LINK, "/mnt/cfg/param/cvi_sdr_bin_GC2083") != CVI_SUCCESS)
			return CVI_FAILURE;
	}

	return link_file(SENSOR_CFG_LINK, ini);
}
