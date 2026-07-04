#!/bin/sh
# health_check.sh — EdgeEye / 安防栈健康检查
#
# 用法：./health_check.sh
# 退出码：0=全部通过，1=存在告警
set -e

WARN=0
ROOT=/root

# shellcheck disable=SC1091
[ -f "$ROOT/edgeeye_cam_common.sh" ] && . "$ROOT/edgeeye_cam_common.sh"
edgeeye_load_config 2>/dev/null || true

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

rtsp_probe_url() {
    url="$1"
    if command -v ffprobe >/dev/null 2>&1; then
        ffprobe -rtsp_transport tcp -v quiet \
            -show_entries stream=width,height,codec_name \
            -of default=nw=1 "$url" 2>/dev/null | grep -q codec_name
        return $?
    fi
    return 1
}

echo "=== edgeeye health check $(date) ==="
echo "       config mode=${EDGEEYE_MODE:-?} port=${EDGEEYE_PORT:-8554} res=${EDGEEYE_RES:-?}"

# ── edgeeye_cam（产品栈）────────────────────────────────────
if edgeeye_cam_alive 2>/dev/null; then
    check "edgeeye_cam running (pid $(cat /tmp/edgeeye_cam_rtsp.pid))" 1
elif proc_alive edgeeye_cam; then
    check "edgeeye_cam running" 1
else
    check "edgeeye_cam running" 0
fi

PORT="${EDGEEYE_PORT:-8554}"
RTSP_BASE="rtsp://127.0.0.1:${PORT}"

if edgeeye_rtsp_port_listening "$PORT" 2>/dev/null; then
    check "RTSP port $PORT listening" 1
else
    check "RTSP port $PORT listening" 0
fi

if rtsp_probe_url "${RTSP_BASE}/cam0"; then
    if command -v ffprobe >/dev/null 2>&1; then
        wh=$(ffprobe -rtsp_transport tcp -v quiet \
            -show_entries stream=width,height \
            -of csv=p=0:s=x "${RTSP_BASE}/cam0" 2>/dev/null | head -1)
        check "RTSP cam0 stream OK (${wh:-unknown})" 1
    else
        check "RTSP cam0 stream OK (ffprobe)" 1
    fi
elif edgeeye_rtsp_port_listening "$PORT" 2>/dev/null; then
    check "RTSP cam0 stream (port up, no ffprobe detail)" 1
else
    check "RTSP cam0 reachable" 0
fi

if [ "${EDGEEYE_MODE:-dual}" = "dual" ]; then
    if rtsp_probe_url "${RTSP_BASE}/cam1"; then
        wh=$(ffprobe -rtsp_transport tcp -v quiet \
            -show_entries stream=width,height \
            -of csv=p=0:s=x "${RTSP_BASE}/cam1" 2>/dev/null | head -1)
        check "RTSP cam1 stream OK (${wh:-unknown})" 1
    elif edgeeye_rtsp_port_listening "$PORT" 2>/dev/null; then
        skip "RTSP cam1 (ffprobe failed; check dual mode)"
    else
        check "RTSP cam1 reachable" 0
    fi
fi

# ── 可选：debris.ko / 旧安防栈 ─────────────────────────────
if lsmod | grep -q '^debris '; then
    check "debris.ko loaded" 1
    if [ -f /proc/debris ]; then
        grep -E 'i2c_ok|sensor_init_ok|motion_count' /proc/debris 2>/dev/null | sed 's/^/       /'
    fi
else
    skip "debris.ko (edgeeye_cam 不依赖驱动)"
fi

if pid_alive /tmp/rtsp_server.pid; then
    check "rtsp_server (legacy) running" 1
else
    skip "rtsp_server (legacy, edgeeye_cam 已替代)"
fi

if [ -f "$ROOT/media_tools.sh" ]; then
    # shellcheck disable=SC1091
    . "$ROOT/media_tools.sh"
fi
if [ -n "$FFMPEG" ] && [ -x "$FFMPEG" ]; then
    check "ffmpeg available ($FFMPEG)" 1
else
    skip "ffmpeg (PC 侧 RTSP 录制即可)"
fi

for p in motion_detect; do
    if proc_alive "$p"; then
        check "$p running" 1
    else
        skip "$p (未启用)"
    fi
done

CLIP_DIR="${CLIP_DIR:-/mnt/sd/clips}"
if [ ! -d "$CLIP_DIR" ]; then
    CLIP_DIR=/mnt/data/clips
fi
if [ -d "$CLIP_DIR" ] && [ -w "$CLIP_DIR" ]; then
    check "clip dir writable ($CLIP_DIR)" 1
else
    skip "clip dir ($CLIP_DIR)"
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

WEB_PORT="${EDGEEYE_WEB_PORT:-8080}"
if [ "${EDGEEYE_WEB:-0}" = "1" ]; then
    if netstat -ln 2>/dev/null | grep -q ":$WEB_PORT " || \
       ss -ln 2>/dev/null | grep -q ":$WEB_PORT"; then
        check "Web UI port $WEB_PORT listening" 1
    else
        check "Web UI port $WEB_PORT listening" 0
    fi
fi

echo "=== done (warn=$WARN) ==="
exit "$WARN"
