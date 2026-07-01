#!/bin/sh
# reset_single_camera.sh — 恢复单摄 OV5647 J2 sensor_cfg（修复 RTSP End of file）
#
# 原因：verify_board / setup_dual_camera 会把 sensor_cfg 链到 dev_num=2，
# 单摄板上会导致 rtsp_server 无有效码流。
set -e

J2="/mnt/data/sensor_cfg_OV5647_J2.ini"
LINK="/mnt/data/sensor_cfg.ini"

if [ ! -f "$J2" ]; then
    echo "missing $J2"
    exit 1
fi

ln -sf "$J2" "$LINK"
echo "sensor_cfg.ini -> $J2"
grep -E 'dev_num|bus_id' "$LINK" || true

if [ -x /root/stream/stop_rtsp.sh ]; then
    sh /root/stream/stop_rtsp.sh 2>/dev/null || true
else
    if [ -f /tmp/rtsp_server.pid ]; then
        kill "$(cat /tmp/rtsp_server.pid)" 2>/dev/null || true
        rm -f /tmp/rtsp_server.pid
    fi
fi
echo "rtsp_server stopped — run: /root/stream/start_rtsp.sh"
