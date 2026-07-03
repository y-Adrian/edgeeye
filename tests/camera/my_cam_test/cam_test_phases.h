/*
 * cam_test_phases.h — my_cam_test 分阶段验收编排
 */
#ifndef CAM_TEST_PHASES_H
#define CAM_TEST_PHASES_H

#include "sample_comm.h"

CVI_S32 cam_test_phase6_validate(void);
CVI_S32 cam_test_capture_yuv_run(const char *single_path);
CVI_S32 cam_test_capture_h264_run(const char *single_path);
CVI_S32 cam_test_rtsp_run(int stream_sec);

CVI_S32 cam_test_phase3_run(const char *single_path);
CVI_S32 cam_test_phase4_run(const char *single_path);
CVI_S32 cam_test_phase5_run(int stream_sec);
CVI_S32 cam_test_phase7_run(void);
CVI_S32 cam_test_phase8_run(void);

#endif /* CAM_TEST_PHASES_H */
