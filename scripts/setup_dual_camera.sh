#!/bin/sh
# setup_dual_camera.sh — 配置双摄 sensor_cfg + RTSP cam_dual.json
#
# 用法：./setup_dual_camera.sh
# 前提：J1/J2 各接一颗 OV5647，DT 中 debris,camera-count=2
set -e

DUAL_INI_SRC="/root/stream/sensor_cfg_OV5647_dual.ini"
DUAL_INI_BOARD="/mnt/data/sensor_cfg_OV5647_dual.ini"
LINK="/mnt/data/sensor_cfg.ini"
CFG="/root/stream/cam_dual.json"

if [ -f "$DUAL_INI_SRC" ]; then
    cp "$DUAL_INI_SRC" "$DUAL_INI_BOARD"
    echo "installed $DUAL_INI_BOARD"
elif [ -f "$DUAL_INI_BOARD" ]; then
    echo "using existing $DUAL_INI_BOARD"
else
    echo "missing dual ini — deploy stream/ first"
    exit 1
fi

ln -sf "$DUAL_INI_BOARD" "$LINK"
echo "linked $LINK -> $DUAL_INI_BOARD"

if [ ! -f "$CFG" ]; then
    echo "missing $CFG"
    exit 1
fi

echo "dual RTSP config: $CFG"
echo "start: ./stream/start_rtsp.sh $CFG"
echo "urls: rtsp://192.168.42.1:8554/cam0 rtsp://192.168.42.1:8554/cam1"
