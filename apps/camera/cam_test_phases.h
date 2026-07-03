/*
 * cam_test_phases.h — 分阶段验收用例（phase 2～8）
 */
#ifndef CAM_TEST_PHASES_H
#define CAM_TEST_PHASES_H

#include "sample_comm.h"

CVI_S32 cam_test_phase6_validate(void);
CVI_S32 cam_test_phase3_run(void);
CVI_S32 cam_test_phase4_run(void);
CVI_S32 cam_test_phase5_run(int stream_sec);
CVI_S32 cam_test_phase7_run(void);
CVI_S32 cam_test_phase8_run(void);

#endif /* CAM_TEST_PHASES_H */
