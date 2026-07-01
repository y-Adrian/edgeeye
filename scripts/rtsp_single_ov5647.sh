#!/bin/sh
# rtsp_single_ov5647.sh — 单摄 J2 OV5647 快速恢复预览
set -e

if [ -x /root/stream/stop_rtsp.sh ]; then
    sh /root/stream/stop_rtsp.sh 2>/dev/null || true
elif [ -f /tmp/rtsp_server.pid ]; then
    kill "$(cat /tmp/rtsp_server.pid)" 2>/dev/null || true
    rm -f /tmp/rtsp_server.pid
fi
sleep 2

ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin

: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 12
echo "OV5647: rtsp://192.168.42.1:8554/cam0"
