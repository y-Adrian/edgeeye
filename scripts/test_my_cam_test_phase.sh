#!/bin/sh
# test_my_cam_test_phase.sh — 按阶段 + 传感器验收 my_cam_test
#
# 用法：
#   ./test_my_cam_test_phase.sh <2|3|4|5> [gc2083|ov5647]
#
# 示例：
#   ./test_my_cam_test_phase.sh 5 ov5647   # J2 OV5647 RTSP
#   ./test_my_cam_test_phase.sh 3 gc2083   # J1 GC2083 抓一帧 YUV
set -e

PHASE="${1:-}"
SENSOR="${2:-gc2083}"
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

case "$PHASE" in
    2|3|4|5) ;;
    *)
        echo "usage: $0 <2|3|4|5> [gc2083|ov5647]"
        echo "  gc2083 = J1 Milk-V CAM-GC2083"
        echo "  ov5647 = J2 树莓派 OV5647"
        exit 1
        ;;
esac

case "$PHASE" in
    2) exec "$DIR/test_my_cam_test.sh" "$SENSOR" ;;
    3) exec "$DIR/test_my_cam_test_phase3.sh" "$SENSOR" ;;
    4) exec "$DIR/test_my_cam_test_phase4.sh" "$SENSOR" ;;
    5) exec "$DIR/test_my_cam_test_phase5.sh" "$SENSOR" ;;
esac
