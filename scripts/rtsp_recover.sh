#!/bin/sh
# rtsp_recover.sh — 单摄 RTSP 急救（双摄试失败后恢复用）
#
# 用法：
#   ./rtsp_recover.sh ov5647    # J2 树莓派头（默认）
#   ./rtsp_recover.sh gc2083    # J1 官方头
#
# 常见故障：sensor_cfg 仍链到 dev_num=2 双摄 ini，却用 cam0.json 启动 → 无画面
set -e

MODE="${1:-ov5647}"
PARAM=/mnt/cfg/param

stop_rtsp_all() {
    /root/stop_security.sh 2>/dev/null || true
    if [ -x /root/stream/stop_rtsp.sh ]; then
        sh /root/stream/stop_rtsp.sh 2>/dev/null || true
    fi
    if [ -f /tmp/rtsp_server.pid ]; then
        kill "$(cat /tmp/rtsp_server.pid)" 2>/dev/null || true
        rm -f /tmp/rtsp_server.pid
    fi
    for _p in $(ps | grep rtsp_server | grep -v grep | awk '{print $1}'); do
        kill "$_p" 2>/dev/null || true
    done
    sleep 2
    if ps | grep rtsp_server | grep -v grep >/dev/null 2>&1; then
        echo "WARN: rtsp_server still running — try: reboot"
    else
        echo "rtsp_server stopped"
    fi
}

rmmod debris 2>/dev/null || true

case "$MODE" in
    ov5647|5647|j2)
        INI=/mnt/data/sensor_cfg_OV5647_J2.ini
        BIN=cvi_sdr_bin_OV5647.bin
        ;;
    gc2083|2083|j1)
        INI=/mnt/data/sensor_cfg_GC2083.ini
        BIN=cvi_sdr_bin_GC2083
        ;;
    *)
        echo "usage: $0 ov5647|gc2083"
        exit 1
        ;;
esac

[ -f "$INI" ] || { echo "missing $INI"; exit 1; }
[ -f "$PARAM/$BIN" ] || { echo "missing $PARAM/$BIN"; exit 1; }

echo "=== RTSP recover: $MODE ==="
stop_rtsp_all

ln -sf "$INI" /mnt/data/sensor_cfg.ini
ln -sf "$BIN" "$PARAM/cvi_sdr_bin"

echo "--- config ---"
ls -la /mnt/data/sensor_cfg.ini "$PARAM/cvi_sdr_bin"
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini

DEVNUM=$(grep -E '^[[:space:]]*dev_num' /mnt/data/sensor_cfg.ini | sed 's/[^0-9]//g')
if [ "$DEVNUM" != "1" ]; then
    echo "ERROR: dev_num=$DEVNUM (need 1 for cam0.json). Fix sensor_cfg link."
    exit 1
fi

export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
: > /tmp/rtsp_server.log
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 14

if ! kill -0 "$(cat /tmp/rtsp_server.pid)" 2>/dev/null; then
    echo "rtsp_server FAILED (进程已退出 → Mac 连不上):"
    tail -40 /tmp/rtsp_server.log
    echo ""
    echo ">>> 双摄失败后 VI/ISP 常僵死，请先: reboot"
    echo ">>> 重启后: /root/rtsp_recover.sh $MODE"
    exit 1
fi

echo "rtsp_server OK pid $(cat /tmp/rtsp_server.pid)"
if ! netstat -ln 2>/dev/null | grep -q ':8554'; then
    echo "WARN: 8554 未监听，等 5s 再查"
    sleep 5
    netstat -ln 2>/dev/null | grep 8554 || echo "8554 still not listening"
fi

grep -iE 'Init OK|mismatch|error|fail|dev_num|sensor =|vi init' /tmp/rtsp_server.log | tail -18 || true
echo ""
echo "preview: ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0"
echo ""
echo "能连上但黑屏: 多为 ISP 未恢复 → reboot 后再跑本脚本"
echo "OV5647 连不上 + GC2083 黑屏: 几乎一定要 reboot"
