#!/bin/sh
# rtsp_preview_only.sh — 仅启动 RTSP 预览（不加载 debris，避免黑屏）
#
# 用法：./rtsp_preview_only.sh
# Mac/VLC：rtsp://192.168.42.1:8554/cam0 :rtsp-tcp
set -e

echo "=== RTSP preview only (no debris.ko) ==="

if [ -x /root/rtsp_recover.sh ]; then
    exec /root/rtsp_recover.sh ov5647
fi

/root/stop_security.sh 2>/dev/null || true
rmmod debris 2>/dev/null || true

ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
if [ -x /root/select_pq_bin.sh ]; then
    /root/select_pq_bin.sh ov5647
elif [ -f /mnt/cfg/param/cvi_sdr_bin_OV5647.bin ]; then
    ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin
    echo "cvi_sdr_bin -> cvi_sdr_bin_OV5647.bin"
fi
echo "sensor_cfg:"
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini

for _p in $(ps | grep rtsp_server | grep -v grep | awk '{print $1}'); do
    kill "$_p" 2>/dev/null || true
done
rm -f /tmp/rtsp_server.pid
sleep 2

export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 12

if kill -0 "$(cat /tmp/rtsp_server.pid)" 2>/dev/null; then
    echo "rtsp_server OK pid $(cat /tmp/rtsp_server.pid)"
else
    echo "rtsp_server FAILED"
    tail -20 /tmp/rtsp_server.log
    exit 1
fi

grep -iE 'mismatch|error|fail|ISP Dev' /tmp/rtsp_server.log | tail -10 || true
echo ""
echo "VLC/ffplay: rtsp://192.168.42.1:8554/cam0"
echo "若仍黑屏：reboot 后再运行本脚本；或试 J1 配置（见文档）"
