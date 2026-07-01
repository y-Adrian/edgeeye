#!/bin/sh
# rtsp_diagnose.sh — 收集 RTSP/摄像头状态（连上无画面 / 连不上时运行）
# 用法：/root/rtsp_diagnose.sh
set -e

echo "========== time / uptime =========="
date 2>/dev/null || true
uptime 2>/dev/null || true

echo ""
echo "========== sensor_cfg =========="
ls -la /mnt/data/sensor_cfg.ini 2>/dev/null || echo "no sensor_cfg.ini"
grep -E 'dev_num|name|bus_id|mipi|lane' /mnt/data/sensor_cfg.ini 2>/dev/null || true

echo ""
echo "========== PQ bin =========="
ls -la /mnt/cfg/param/cvi_sdr_bin* 2>/dev/null || true

echo ""
echo "========== I2C =========="
i2cdetect -y 2 2>/dev/null | head -8 || true
i2cdetect -y 3 2>/dev/null | head -8 || true

echo ""
echo "========== rtsp_server =========="
if [ -f /tmp/rtsp_server.pid ]; then
    echo "pidfile: $(cat /tmp/rtsp_server.pid)"
    kill -0 "$(cat /tmp/rtsp_server.pid)" 2>/dev/null && echo "process: alive" || echo "process: DEAD"
else
    echo "no pidfile"
fi
ps | grep rtsp_server | grep -v grep || echo "no rtsp_server in ps"
netstat -ln 2>/dev/null | grep 8554 || echo "8554 not listening"

echo ""
echo "========== debris =========="
lsmod 2>/dev/null | grep debris || echo "debris not loaded"

echo ""
echo "========== rtsp log (key lines) =========="
if [ -f /tmp/rtsp_server.log ]; then
    wc -l /tmp/rtsp_server.log
    grep -iE 'sensor =|dev_num|devNum|GC2083|OV5647|Init OK|mismatch|vi init|fail|error|ISP Dev' \
        /tmp/rtsp_server.log | tail -25 || true
    echo "--- tail 15 ---"
    tail -15 /tmp/rtsp_server.log
else
    echo "no /tmp/rtsp_server.log"
fi

echo ""
echo "========== dmesg (mipi/vi) =========="
dmesg 2>/dev/null | grep -iE 'mipi|vi |isp|sensor|error' | tail -15 || true

echo ""
echo "========== Mac 侧建议 =========="
echo "ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0"
echo "ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 10 t.mp4"
echo "ffprobe -show_entries stream=bit_rate -of default=nw=1 t.mp4  # 黑屏常 <100k"
