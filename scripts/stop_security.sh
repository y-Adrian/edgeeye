#!/bin/sh
# stop_security.sh — 停止安防栈并卸载 debris.ko
set -e

for s in stop_rtsp.sh stop_motion_watch.sh stop_motion_recorder.sh; do
    if [ -x "/root/stream/$s" ]; then
        sh "/root/stream/$s" 2>/dev/null || true
    elif [ -x "/root/$s" ]; then
        sh "/root/$s" 2>/dev/null || true
    fi
done

for f in /tmp/motion_detect.pid /tmp/motion_detect_v4l2.pid /tmp/motion_recorder.pid; do
    if [ -f "$f" ]; then
        kill "$(cat "$f")" 2>/dev/null || true
        rm -f "$f"
    fi
done

rmmod debris 2>/dev/null || true
echo "debris security stopped"
