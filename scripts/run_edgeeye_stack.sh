#!/bin/sh
# run_edgeeye_stack.sh — 完整产品栈：RTSP + 可选动检录像 + Web 快照页
#
# 读 edgeeye_cam.conf；日志 /tmp/edgeeye_stack.log
set -e

BOARD_DIR=/root
LOG=/tmp/edgeeye_stack.log
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh"
edgeeye_load_config

echo "=== run_edgeeye_stack $(date) mode=$EDGEEYE_MODE record=$EDGEEYE_RECORD web=$EDGEEYE_WEB ai=$EDGEEYE_AI live=${EDGEEYE_WEB_LIVE:-hls} ===" | tee "$LOG"

if [ -n "$EDGEEYE_BOOT_DELAY" ] && [ "$EDGEEYE_BOOT_DELAY" -gt 0 ] 2>/dev/null; then
	echo "boot_delay ${EDGEEYE_BOOT_DELAY}s..." | tee -a "$LOG"
	sleep "$EDGEEYE_BOOT_DELAY"
fi

if [ ! -x "$BOARD_DIR/edgeeye_cam" ]; then
	echo "missing $BOARD_DIR/edgeeye_cam" | tee -a "$LOG"
	exit 1
fi

if ! sh "$DIR/start_my_cam_rtsp.sh" "$EDGEEYE_MODE" \
	--port "$EDGEEYE_PORT" --res "$EDGEEYE_RES" >>"$LOG" 2>&1; then
	echo "ERROR: edgeeye_cam failed to start" | tee -a "$LOG"
	if [ "$EDGEEYE_MODE" = "dual" ]; then
		echo "双摄 VPSS/ION 失败时请先 reboot，再执行: $0" | tee -a "$LOG"
	fi
	exit 1
fi

if ! edgeeye_cam_alive; then
	echo "ERROR: edgeeye_cam not running (stale pid?)" | tee -a "$LOG"
	exit 1
fi

if ! edgeeye_wait_rtsp_ready 90; then
	echo "WARN: RTSP not confirmed ready" | tee -a "$LOG"
fi

edgeeye_start_recording "$LOG"
edgeeye_start_ai "$LOG"

if [ "$EDGEEYE_WEB" = "1" ] && [ -x "$DIR/serve_edgeeye_web.sh" ]; then
	sh "$DIR/serve_edgeeye_web.sh" >>"$LOG" 2>&1 || \
		echo "WARN: web serve failed" | tee -a "$LOG"
else
	echo "web disabled (web=$EDGEEYE_WEB)" | tee -a "$LOG"
fi

echo "stack ready port=$EDGEEYE_PORT web=${EDGEEYE_WEB:-0}:${EDGEEYE_WEB_PORT:-8080}/${EDGEEYE_WEB_LIVE:-hls} record=${EDGEEYE_RECORD:-0} ai=${EDGEEYE_AI:-0}" | tee -a "$LOG"
