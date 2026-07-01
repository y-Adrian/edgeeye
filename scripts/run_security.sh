#!/bin/sh
# run_security.sh — 安防完整栈一键启动（开发板 /root 下运行）
#
# 用法：./run_security.sh [gpio_btn]
# 环境：DEBRIS_DUAL=1 启用双摄 RTSP + 双路录像
set -e

BOARD_DIR=/root
GPIO_BTN="${1:--1}"
LOG=/tmp/debris_security.log
CLIP_SEC="${CLIP_SEC:-30}"
COOLDOWN_SEC="${COOLDOWN_SEC:-15}"

cd "$BOARD_DIR"

echo "=== debris security $(date) ===" | tee "$LOG"

if ! lsmod | grep -q '^debris '; then
    if [ "$GPIO_BTN" -ge 0 ] 2>/dev/null; then
        insmod "$BOARD_DIR/debris.ko" register_fallback_pdev=0 gpio_btn="$GPIO_BTN" \
            i2c_sensor_mode="${I2C_SENSOR_MODE:-0}"
    else
        insmod "$BOARD_DIR/debris.ko" register_fallback_pdev=0 \
            i2c_sensor_mode="${I2C_SENSOR_MODE:-0}"
    fi
fi

if [ -x "$BOARD_DIR/check_vendor_media.sh" ]; then
    sh "$BOARD_DIR/check_vendor_media.sh" | tee -a "$LOG"
fi

RTSP_CFG="$BOARD_DIR/stream/cam0.json"
if [ "${DEBRIS_DUAL:-0}" = "1" ] && [ -f "$BOARD_DIR/stream/cam_dual.json" ]; then
    if [ -x "$BOARD_DIR/setup_dual_camera.sh" ]; then
        sh "$BOARD_DIR/setup_dual_camera.sh" >> "$LOG" 2>&1 || true
    fi
    RTSP_CFG="$BOARD_DIR/stream/cam_dual.json"
elif [ -f /mnt/data/sensor_cfg_OV5647_J2.ini ]; then
    ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
    echo "sensor_cfg.ini -> OV5647_J2 (single cam)" | tee -a "$LOG"
    if [ -x "$BOARD_DIR/select_pq_bin.sh" ]; then
        sh "$BOARD_DIR/select_pq_bin.sh" ov5647 >> "$LOG" 2>&1 || true
    elif [ -f /mnt/cfg/param/cvi_sdr_bin_OV5647.bin ]; then
        ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
    fi
fi

if [ -x "$BOARD_DIR/stream/start_rtsp.sh" ]; then
    echo "starting RTSP ($RTSP_CFG)..." | tee -a "$LOG"
    sh "$BOARD_DIR/stream/start_rtsp.sh" "$RTSP_CFG" >> "$LOG" 2>&1 || \
        echo "RTSP start skipped (see log)" | tee -a "$LOG"
fi

if [ -x "$BOARD_DIR/motion_detect" ]; then
    echo "starting motion_detect..." | tee -a "$LOG"
    "$BOARD_DIR/motion_detect" 64 120 >> "$LOG" 2>&1 &
    echo $! > /tmp/motion_detect.pid
fi

if [ -e /dev/video0 ] && [ -x "$BOARD_DIR/motion_detect_v4l2" ]; then
    echo "starting motion_detect_v4l2..." | tee -a "$LOG"
    "$BOARD_DIR/motion_detect_v4l2" /dev/video0 5000 60 >> "$LOG" 2>&1 &
    echo $! > /tmp/motion_detect_v4l2.pid
else
    echo "skip v4l2 motion (/dev/video0 not ready)" | tee -a "$LOG"
fi

if [ -x "$BOARD_DIR/motion_recorder" ]; then
    if [ -f "$BOARD_DIR/media_tools.sh" ]; then
        # shellcheck disable=SC1091
        . "$BOARD_DIR/media_tools.sh"
        export FFMPEG
    fi
    if [ -n "$FFMPEG" ] || command -v ffmpeg >/dev/null 2>&1; then
        echo "starting motion_recorder (clip ${CLIP_SEC}s)..." | tee -a "$LOG"
        if [ "${DEBRIS_DUAL:-0}" = "1" ]; then
            export RTSP_URL2="${RTSP_URL2:-rtsp://127.0.0.1:8554/cam1}"
        fi
        "$BOARD_DIR/motion_recorder" "$CLIP_SEC" "$COOLDOWN_SEC" >> "$LOG" 2>&1 &
        echo $! > /tmp/motion_recorder.pid
    else
        echo "skip motion_recorder (ffmpeg not on board; use PC RTSP record)" | tee -a "$LOG"
    fi
fi

if [ -x "$BOARD_DIR/motion_watch.sh" ]; then
    sh "$BOARD_DIR/motion_watch.sh" >> "$LOG" 2>&1 || true
fi

if [ -x "$BOARD_DIR/health_check.sh" ]; then
    sh "$BOARD_DIR/health_check.sh" | tee -a "$LOG" || true
fi

CLIP_DIR="${CLIP_DIR:-/mnt/sd/clips}"
[ -d "$CLIP_DIR" ] || CLIP_DIR=/mnt/data/clips
echo "log: $LOG" | tee -a "$LOG"
echo "clips: $CLIP_DIR" | tee -a "$LOG"
echo "PIDs: motion=$(cat /tmp/motion_detect.pid 2>/dev/null) rtsp=$(cat /tmp/rtsp_server.pid 2>/dev/null) recorder=$(cat /tmp/motion_recorder.pid 2>/dev/null)" | tee -a "$LOG"
echo "=== started ===" | tee -a "$LOG"
