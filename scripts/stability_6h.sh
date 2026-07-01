#!/bin/sh
# stability_6h.sh — 长稳测试（默认 6 小时，可改 DURATION_SEC）
#
# 用法：./stability_6h.sh [hours]
# 日志：/tmp/stability_6h.log
# 指标：进程存活、/proc/debris、磁盘、温度、RTSP（若 ffprobe 可用）
set -e

HOURS="${1:-6}"
DURATION_SEC=$((HOURS * 3600))
INTERVAL="${INTERVAL_SEC:-300}"
LOG=/tmp/stability_6h.log
METRICS=/tmp/stability_metrics.csv
END=$(( $(date +%s) + DURATION_SEC ))

echo "stability run: ${HOURS}h interval=${INTERVAL}s" | tee "$LOG"
echo "end: $(date -d "@$END" 2>/dev/null || date -r "$END" 2>/dev/null || echo "@$END")" | tee -a "$LOG"

echo "ts,debris,rtsp,motion_rec,motion_v4l2,clip_kb,thermal_mC,temp_warn" > "$METRICS"

iter=0
while [ "$(date +%s)" -lt "$END" ]; do
    iter=$((iter + 1))
    ts=$(date '+%Y-%m-%dT%H:%M:%S')

    debris=0
    lsmod | grep -q '^debris ' && debris=1

    rtsp=0
    [ -f /tmp/rtsp_server.pid ] && kill -0 "$(cat /tmp/rtsp_server.pid)" 2>/dev/null && rtsp=1

    rec=0
    pgrep -x motion_recorder >/dev/null 2>&1 && rec=1

    v4l2=0
    pgrep -x motion_detect_v4l2 >/dev/null 2>&1 && v4l2=1

    clip_kb=0
    CLIP_DIR="${CLIP_DIR:-/mnt/sd/clips}"
    [ -d "$CLIP_DIR" ] || CLIP_DIR=/mnt/data/clips
    if [ -d "$CLIP_DIR" ]; then
        clip_kb=$(du -sk "$CLIP_DIR" 2>/dev/null | awk '{print $1}')
    fi

    thermal=0
    temp_warn=0
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        thermal=$(cat /sys/class/thermal/thermal_zone0/temp)
        [ "$thermal" -gt 85000 ] 2>/dev/null && temp_warn=1
    fi

    echo "$ts,$debris,$rtsp,$rec,$v4l2,$clip_kb,$thermal,$temp_warn" >> "$METRICS"
    echo "[$iter] $ts debris=$debris rtsp=$rtsp rec=$rec v4l2=$v4l2 clips=${clip_kb}KB thermal=${thermal}" | tee -a "$LOG"

    if [ -x /root/health_check.sh ]; then
        sh /root/health_check.sh >> "$LOG" 2>&1 || true
    fi

    sleep "$INTERVAL"
done

echo "stability complete after ${HOURS}h" | tee -a "$LOG"
echo "metrics: $METRICS"
