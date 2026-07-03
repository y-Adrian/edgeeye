#!/bin/sh
# run_edgeeye_cam.sh — 按配置启动 edgeeye_cam（开机自启 / 手动）
#
# 读 /root/edgeeye_cam.conf，调用 start_my_cam_rtsp.sh
# 日志：/tmp/edgeeye_autostart.log
set -e

BOARD_DIR=/root
LOG=/tmp/edgeeye_autostart.log
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh"
edgeeye_load_config

echo "=== run_edgeeye_cam $(date) mode=$EDGEEYE_MODE port=$EDGEEYE_PORT res=$EDGEEYE_RES ===" | tee -a "$LOG"

if [ -n "$EDGEEYE_BOOT_DELAY" ] && [ "$EDGEEYE_BOOT_DELAY" -gt 0 ] 2>/dev/null; then
	echo "boot_delay ${EDGEEYE_BOOT_DELAY}s..." | tee -a "$LOG"
	sleep "$EDGEEYE_BOOT_DELAY"
fi

if [ ! -x "$BOARD_DIR/edgeeye_cam" ]; then
	echo "missing $BOARD_DIR/edgeeye_cam — deploy first" | tee -a "$LOG"
	exit 1
fi

exec sh "$DIR/start_my_cam_rtsp.sh" "$EDGEEYE_MODE" \
	--port "$EDGEEYE_PORT" --res "$EDGEEYE_RES" >>"$LOG" 2>&1
