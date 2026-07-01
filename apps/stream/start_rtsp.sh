#!/bin/sh
# start_rtsp.sh — 启动 vendor rtsp_server（VI/VENC/RTSP MVP）
#
# 用法：./start_rtsp.sh [json_path]
# 默认配置：/root/stream/cam0.json → rtsp://<board>:8554/cam0
#
# 前提：BSP 已安装 /mnt/system/usr/test/rtsp_server 与 sensor_cfg.ini
set -e

export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:${LD_LIBRARY_PATH}

RTSP_BIN="${RTSP_BIN:-/mnt/system/usr/test/rtsp_server}"
CFG="${1:-/root/stream/cam0.json}"
PIDFILE=/tmp/rtsp_server.pid

if [ ! -x "$RTSP_BIN" ]; then
    echo "start_rtsp: $RTSP_BIN not found"
    echo "Build SDK: source envsetup && build_middleware && build_cvi_rtsp"
    exit 1
fi

if [ ! -f "$CFG" ]; then
    echo "start_rtsp: missing config $CFG"
    exit 1
fi

if [ ! -f /mnt/data/sensor_cfg.ini ]; then
    if [ -f /mnt/data/sensor_cfg_OV5647_J2.ini ]; then
        ln -sf /mnt/data/sensor_cfg_OV5647_J2.ini /mnt/data/sensor_cfg.ini
        echo "linked sensor_cfg.ini -> OV5647_J2"
    else
        echo "warn: /mnt/data/sensor_cfg.ini missing"
    fi
fi

if [ -f "$PIDFILE" ]; then
    if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "rtsp_server already running pid $(cat "$PIDFILE")"
        echo "stop first: /root/stream/stop_rtsp.sh"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

"$RTSP_BIN" "$CFG" >> /tmp/rtsp_server.log 2>&1 &
echo $! > "$PIDFILE"

IP=$(ip -4 addr show usb0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
[ -z "$IP" ] && IP=192.168.42.1

echo "rtsp_server started pid $(cat "$PIDFILE")"
echo "log: /tmp/rtsp_server.log"
echo "preview: ffplay -rtsp_transport tcp rtsp://${IP}:8554/cam0"
echo "dual config uses cam0 + cam1 when sensor_cfg dev_num=2"
