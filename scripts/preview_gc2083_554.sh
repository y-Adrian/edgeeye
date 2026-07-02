#!/bin/sh
# preview_gc2083_554.sh — J1 GC2083 已验证预览（camera-test → 554/h264）
#
# ISSUE-002 收口：rtsp_server @8554 对 GC2083 无画面；本脚本为当前权威路径。
# 用法：./preview_gc2083_554.sh
# Mac：ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264
# 注意：camera-test 阻塞前台运行，Ctrl+C 结束。
set -e

echo "=== GC2083 preview (554/h264 via camera-test) ==="

for _p in $(ps | grep -E 'sample_vi|rtsp_server' | grep -v grep | awk '{print $1}'); do
    kill "$_p" 2>/dev/null || true
done
rm -f /tmp/rtsp_server.pid
sleep 2
rmmod debris 2>/dev/null || true

ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin

echo "sensor_cfg:"
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini

export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd

echo ""
echo "Starting camera-test (keep this terminal open)..."
echo "Mac: ffplay -rtsp_transport tcp rtsp://192.168.42.1:554/h264"
echo ""

exec sh /mnt/system/usr/bin/camera-test.sh
