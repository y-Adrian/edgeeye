#!/bin/sh
# rtsp_dual_mixed.sh — 启动混搭双摄 RTSP（J1 GC2083 + J2 OV5647）
set -e

echo "=== Mixed dual RTSP (GC2083 cam0 + OV5647 cam1) ==="

/root/stop_security.sh 2>/dev/null || true
if [ -x /root/stream/stop_rtsp.sh ]; then
    sh /root/stream/stop_rtsp.sh 2>/dev/null || true
elif [ -f /tmp/rtsp_server.pid ]; then
    kill "$(cat /tmp/rtsp_server.pid)" 2>/dev/null || true
    rm -f /tmp/rtsp_server.pid
fi
sleep 2

if [ -x /root/setup_mixed_dual_camera.sh ]; then
    sh /root/setup_mixed_dual_camera.sh
else
    ln -sf /mnt/data/sensor_cfg_GC2083_OV5647_dual.ini /mnt/data/sensor_cfg.ini
fi

# 先试 GC2083 bin（cam0 优先）；若 cam1 黑，改链 OV5647 或换合并 bin
if [ -f /mnt/cfg/param/cvi_sdr_bin_GC2083 ]; then
    ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin
    echo "cvi_sdr_bin -> GC2083 (cam0 优先；cam1 若黑见文档阶段 F)"
fi

: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam_dual.json
sleep 15

if kill -0 "$(cat /tmp/rtsp_server.pid)" 2>/dev/null; then
    echo "rtsp_server OK pid $(cat /tmp/rtsp_server.pid)"
else
    echo "rtsp_server FAILED"
    tail -25 /tmp/rtsp_server.log
    exit 1
fi

grep -iE 'dev_num|devNum|GC2083|OV5647|Init OK|mismatch|sensorName|error|fail|VPSS|rtspURL' /tmp/rtsp_server.log | tail -25 || true
echo ""
echo "日志应含: *** dev_num:2  且 rtspURL:cam0 / cam1"
echo "cam0 (J1 GC2083): rtsp://192.168.42.1:8554/cam0"
echo "cam1 (J2 OV5647): rtsp://192.168.42.1:8554/cam1"
echo ""
echo "若仍无画面: 先恢复单摄验证 — /root/rtsp_preview_only.sh"
