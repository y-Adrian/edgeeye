#!/bin/sh
# stability_6h.sh — 长稳测试（edgeeye_cam 双摄）
#
# 用法：./stability_6h.sh [hours]
# 日志：/tmp/stability_6h.log
# 指标：/tmp/stability_metrics.csv
set -e

HOURS="${1:-6}"
DURATION_SEC=$((HOURS * 3600))
INTERVAL="${INTERVAL_SEC:-300}"
LOG=/tmp/stability_6h.log
METRICS=/tmp/stability_metrics.csv
END=$(( $(date +%s) + DURATION_SEC ))

ROOT=/root
# shellcheck disable=SC1091
[ -f "$ROOT/edgeeye_cam_common.sh" ] && . "$ROOT/edgeeye_cam_common.sh"
edgeeye_load_config 2>/dev/null || true

rtsp_probe() {
	url="$1"
	command -v ffprobe >/dev/null 2>&1 || return 1
	ffprobe -rtsp_transport tcp -v quiet \
		-show_entries stream=codec_name \
		-of default=nw=1 "$url" 2>/dev/null | grep -q codec_name
}

echo "stability run: ${HOURS}h interval=${INTERVAL}s mode=${EDGEEYE_MODE:-?}" | tee "$LOG"
echo "end: $(date -d "@$END" 2>/dev/null || date -r "$END" 2>/dev/null || echo "@$END")" | tee -a "$LOG"

echo "ts,edgeeye_cam,port_listen,cam0_ok,cam1_ok,recorder,clip_kb,thermal_mC,temp_warn" > "$METRICS"

PORT="${EDGEEYE_PORT:-8554}"
RTSP0="rtsp://127.0.0.1:${PORT}/cam0"
RTSP1="rtsp://127.0.0.1:${PORT}/cam1"

iter=0
while [ "$(date +%s)" -lt "$END" ]; do
	iter=$((iter + 1))
	ts=$(date '+%Y-%m-%dT%H:%M:%S')

	cam=0
	edgeeye_cam_alive 2>/dev/null && cam=1

	listen=0
	edgeeye_rtsp_port_listening "$PORT" 2>/dev/null && listen=1

	c0=0
	c1=0
	[ "$listen" -eq 1 ] && rtsp_probe "$RTSP0" && c0=1
	if [ "${EDGEEYE_MODE:-dual}" = "dual" ] && [ "$listen" -eq 1 ]; then
		rtsp_probe "$RTSP1" && c1=1
	fi

	rec=0
	[ -f /tmp/motion_recorder.pid ] && kill -0 "$(cat /tmp/motion_recorder.pid)" 2>/dev/null && rec=1

	clip_kb=0
	CLIP_DIR="${CLIP_DIR:-/mnt/sd/clips}"
	[ -d "$CLIP_DIR" ] || CLIP_DIR=/mnt/data/clips
	[ -d "$CLIP_DIR" ] && clip_kb=$(du -sk "$CLIP_DIR" 2>/dev/null | awk '{print $1}')

	thermal=0
	temp_warn=0
	if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
		thermal=$(cat /sys/class/thermal/thermal_zone0/temp)
		[ "$thermal" -gt 85000 ] 2>/dev/null && temp_warn=1
	fi

	echo "$ts,$cam,$listen,$c0,$c1,$rec,$clip_kb,$thermal,$temp_warn" >> "$METRICS"
	echo "[$iter] $ts cam=$cam listen=$listen c0=$c0 c1=$c1 rec=$rec clips=${clip_kb}KB thermal=${thermal}" | tee -a "$LOG"

	if [ -x /root/health_check.sh ]; then
		sh /root/health_check.sh >> "$LOG" 2>&1 || true
	fi

	sleep "$INTERVAL"
done

echo "stability complete after ${HOURS}h" | tee -a "$LOG"
echo "metrics: $METRICS"
