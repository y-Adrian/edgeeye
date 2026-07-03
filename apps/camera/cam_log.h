/*
 * cam_log.h — EdgeEye camera pipeline logging
 */
#ifndef CAM_LOG_H
#define CAM_LOG_H

#include <stdio.h>

#define CAM_LOG(fmt, ...) printf("edgeeye_cam: " fmt, ##__VA_ARGS__)

#endif /* CAM_LOG_H */
