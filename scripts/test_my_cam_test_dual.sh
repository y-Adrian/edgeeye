#!/bin/sh
# test_my_cam_test_dual.sh — 双摄统一验收（phase 2～5，dev_num=2 ini）
#
# 用法：./test_my_cam_test_dual.sh <2|3|4|5>
set -e

PHASE="${1:-}"
BIN="${MY_CAM_TEST:-/root/my_cam_test}"
HOLD="${HOLD_SEC:-10}"
STREAM_SEC="${STREAM_SEC:-20}"
PORT="${RTSP_PORT:-8554}"
OUT0_YUV="${DUAL_CAM0_YUV:-/tmp/cam0.yuv}"
OUT1_YUV="${DUAL_CAM1_YUV:-/tmp/cam1.yuv}"
OUT0_H264="${DUAL_CAM0_H264:-/tmp/cam0.h264}"
OUT1_H264="${DUAL_CAM1_H264:-/tmp/cam1.h264}"
YUV_MIN=$((1920 * 1080 * 3 / 2))
H264_MIN=1024
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

case "$PHASE" in
2|3|4|5) ;;
*)
	echo "usage: $0 <2|3|4|5>"
	exit 1
	;;
esac

. "$DIR/my_cam_test_common.sh"
my_cam_assert_bin || exit 1
my_cam_install_sensor_configs

echo "=== test_my_cam_test dual phase $PHASE (unified) ==="

my_cam_stop_media
my_cam_link_dual_sensor
my_cam_tmp_cleanup

LOG="/tmp/my_cam_test_dual_p${PHASE}.log"
rm -f "$LOG"

case "$PHASE" in
2)
	"$BIN" -p 2 -s "$HOLD" >"$LOG" 2>&1
	cat "$LOG"
	my_cam_assert_log 'dev_num=2' "$LOG" || exit 1
	my_cam_assert_log 'dual' "$LOG" 'dual mode' || exit 1
	my_cam_assert_log 'Init OK' "$LOG" || exit 1
	INIT_CNT=$(grep -c 'Init OK' "$LOG" 2>/dev/null || echo 0)
	if [ "$INIT_CNT" -lt 2 ]; then
		echo "FAIL: expected >=2 Init OK, got $INIT_CNT"
		exit 1
	fi
	my_cam_assert_log 'PASSED (phase 2)' "$LOG" || exit 1
	;;
3)
	rm -f "$OUT0_YUV" "$OUT1_YUV"
	"$BIN" -p 3 >"$LOG" 2>&1
	cat "$LOG"
	my_cam_assert_log 'dual VPSS capture OK' "$LOG" || exit 1
	my_cam_assert_log 'PASSED (phase 3)' "$LOG" || exit 1
	my_cam_assert_file_min "$OUT0_YUV" "$YUV_MIN" || exit 1
	my_cam_assert_file_min "$OUT1_YUV" "$YUV_MIN" || exit 1
	;;
4)
	rm -f "$OUT0_H264" "$OUT1_H264"
	"$BIN" -p 4 >"$LOG" 2>&1
	cat "$LOG"
	my_cam_assert_log 'start save from IDR' "$LOG" || exit 1
	my_cam_assert_log 'dual VENC capture OK' "$LOG" || exit 1
	my_cam_assert_log 'PASSED (phase 4)' "$LOG" || exit 1
	my_cam_assert_file_min "$OUT0_H264" "$H264_MIN" || exit 1
	my_cam_assert_file_min "$OUT1_H264" "$H264_MIN" || exit 1
	;;
5)
	"$BIN" -p 5 -s "$STREAM_SEC" -P "$PORT" >"$LOG" 2>&1 &
	PID=$!
	sleep 5
	wait "$PID"
	RC=$?
	cat "$LOG"
	if [ "$RC" -ne 0 ]; then
		echo "FAIL: my_cam_test exited $RC"
		exit 1
	fi
	my_cam_assert_log 'RTSP session chn0' "$LOG" 'cam0 session' || exit 1
	my_cam_assert_log 'RTSP session chn1' "$LOG" 'cam1 session' || exit 1
	my_cam_assert_log 'RTSP streamed' "$LOG" || exit 1
	my_cam_assert_log 'PASSED (phase 5)' "$LOG" || exit 1
	;;
esac

echo "=== PASSED dual phase $PHASE (unified) ==="
