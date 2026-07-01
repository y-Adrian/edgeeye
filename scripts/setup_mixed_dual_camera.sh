#!/bin/sh
# setup_mixed_dual_camera.sh — J1 GC2083 + J2 OV5647 混搭双摄
#
# 用法：./setup_mixed_dual_camera.sh
# RTSP：rtsp://<板子>:8554/cam0（GC2083）  rtsp://<板子>:8554/cam1（OV5647）
#
# PQ bin：单文件 cvi_sdr_bin 内需含两路 ISP 调参；无合并 bin 时 cam1 可能黑/偏色。
# 见 docs/CAMERA_VERIFY.md 阶段 F。
set -e

MIXED_INI_SRC="/root/stream/sensor_cfg_GC2083_OV5647_dual.ini"
MIXED_INI_BOARD="/mnt/data/sensor_cfg_GC2083_OV5647_dual.ini"
LINK="/mnt/data/sensor_cfg.ini"
CFG="/root/stream/cam_dual.json"

if [ -f "$MIXED_INI_SRC" ]; then
    cp "$MIXED_INI_SRC" "$MIXED_INI_BOARD"
    echo "installed $MIXED_INI_BOARD"
elif [ -f "$MIXED_INI_BOARD" ]; then
    echo "using existing $MIXED_INI_BOARD"
else
    echo "missing mixed dual ini — deploy stream/ first"
    exit 1
fi

ln -sf "$MIXED_INI_BOARD" "$LINK"
echo "linked $LINK -> $MIXED_INI_BOARD"
grep -E 'dev_num|name|bus_id' "$LINK" || true

if [ ! -f "$CFG" ]; then
    echo "missing $CFG"
    exit 1
fi

echo ""
echo "PQ bin hint: dual needs merged cvi_sdr_bin (GC2083+OV5647) or trial:"
echo "  ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin   # cam0 ok, cam1 may fail"
echo "  ln -sf cvi_sdr_bin_OV5647.bin /mnt/cfg/param/cvi_sdr_bin # cam1 ok, cam0 may fail"
echo ""
echo "start:"
echo "  /root/stream/stop_rtsp.sh"
echo "  /root/stream/start_rtsp.sh $CFG"
echo "preview:"
echo "  ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0"
echo "  ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam1"
