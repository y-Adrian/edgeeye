#!/bin/sh
# health_check.sh — 安防栈基础健康检查
#
# 用法：./health_check.sh
# 退出码：0=全部通过，1=存在告警
set -e

WARN=0

check() {
    name="$1"
    ok="$2"
    if [ "$ok" = "1" ]; then
        echo "[OK]   $name"
    else
        echo "[WARN] $name"
        WARN=1
    fi
}

skip() {
    echo "[SKIP] $1"
}

pid_alive() {
    pf="$1"
    [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null
}

proc_alive() {
    name="$1"
    pf="/tmp/${name}.pid"
    if pid_alive "$pf"; then
        return 0
    fi
    pgrep -f "/${name}" >/dev/null 2>&1 || pgrep -x "$name" >/dev/null 2>&1
}

echo "=== debris health check $(date) ==="

if lsmod | grep -q '^debris '; then
    check "debris.ko loaded" 1
else
    check "debris.ko loaded" 0
fi

if [ -f /proc/debris ]; then
    check "/proc/debris" 1
    grep -E 'i2c_ok|sensor_init_ok|motion_count' /proc/debris 2>/dev/null | sed 's/^/       /'
else
    check "/proc/debris" 0
fi

if pid_alive /tmp/rtsp_server.pid; then
    check "rtsp_server running" 1
else
    check "rtsp_server running" 0
fi

if [ -f /root/media_tools.sh ]; then
    # shellcheck disable=SC1091
    . /root/media_tools.sh
fi
HAVE_FFMPEG=0
if [ -n "$FFMPEG" ] && [ -x "$FFMPEG" ]; then
    HAVE_FFMPEG=1
    check "ffmpeg available ($FFMPEG)" 1
else
    skip "ffmpeg (install from SDK OSS or record on PC via RTSP)"
fi

for p in motion_detect; do
    if proc_alive "$p"; then
        check "$p running" 1
    else
        check "$p running" 0
    fi
done

if [ "$HAVE_FFMPEG" = "1" ]; then
    if proc_alive motion_recorder; then
        check "motion_recorder running" 1
    else
        check "motion_recorder running" 0
    fi
else
    skip "motion_recorder (no ffmpeg on board)"
fi

if [ -e /dev/video0 ]; then
    if proc_alive motion_detect_v4l2; then
        check "motion_detect_v4l2 running" 1
    else
        check "motion_detect_v4l2 running" 0
    fi
else
    skip "motion_detect_v4l2 (/dev/video0 absent)"
fi

CLIP_DIR="${CLIP_DIR:-/mnt/sd/clips}"
if [ ! -d "$CLIP_DIR" ]; then
    CLIP_DIR=/mnt/data/clips
fi
if [ -d "$CLIP_DIR" ] && [ -w "$CLIP_DIR" ]; then
    check "clip dir writable ($CLIP_DIR)" 1
else
    check "clip dir writable ($CLIP_DIR)" 0
fi

for mount in /mnt/sd /mnt/data; do
    if [ -d "$mount" ]; then
        free_kb=$(df -k "$mount" 2>/dev/null | awk 'NR==2{print $4}')
        echo "       $mount free: ${free_kb:-?} KB"
        if [ -n "$free_kb" ] && [ "$free_kb" -lt 51200 ]; then
            check "$mount disk space (>50MB)" 0
        else
            check "$mount disk space (>50MB)" 1
        fi
    fi
done

if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    t=$(cat /sys/class/thermal/thermal_zone0/temp)
    echo "       thermal_zone0: $t m°C"
fi

if command -v ffprobe >/dev/null 2>&1; then
    if ffprobe -rtsp_transport tcp -v quiet \
        -show_entries stream=codec_name \
        -of default=nw=1 \
        rtsp://127.0.0.1:8554/cam0 2>/dev/null | grep -q codec_name; then
        check "RTSP cam0 reachable (ffprobe)" 1
    else
        check "RTSP cam0 reachable (ffprobe)" 0
    fi
elif netstat -ln 2>/dev/null | grep -q ':8554'; then
    check "RTSP port 8554 listening" 1
elif ss -ln 2>/dev/null | grep -q ':8554'; then
    check "RTSP port 8554 listening" 1
else
    skip "RTSP stream probe (use PC: ffplay rtsp://192.168.42.1:8554/cam0)"
fi

echo "=== done (warn=$WARN) ==="
exit "$WARN"
