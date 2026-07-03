/*
 * cam_sensor_setup.h — 板端 sensor_cfg.ini 软链（单摄/双摄）
 */
#ifndef CAM_SENSOR_SETUP_H
#define CAM_SENSOR_SETUP_H

#include "sample_comm.h"

typedef enum {
	CAM_SENSOR_GC2083 = 0,
	CAM_SENSOR_OV5647,
} cam_sensor_id_e;

typedef enum {
	CAM_LAYOUT_SINGLE = 0,
	CAM_LAYOUT_DUAL,
} cam_layout_e;

CVI_S32 cam_sensor_setup(cam_layout_e layout, cam_sensor_id_e single_sensor);

#endif /* CAM_SENSOR_SETUP_H */
