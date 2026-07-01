#!/bin/sh
# test_single_cam.sh — 单摄调通（J1 GC2083 或 J2 OV5647）
#
# 用法：
#   ./test_single_cam.sh gc2083
#   ./test_single_cam.sh ov5647
#
# 通过标准（板上日志）：
#   - dev_num = 1
#   - 对应 Init OK
#   - rtsp_server 进程存活，8554 监听
# Mac 验证见脚本末尾提示（ffprobe 码率）
set -e

MODE="${1:-}"
PARAM=/mnt/cfg/param
LOG=/tmp/rtsp_server.log
PIDF=/tmp/rtsp_server.pid

usage() {
    echo "usage: $0 gc2083|ov5647"
    echo "  gc2083  J1 / i2c-3 / 0x37  官方模组"
    echo "  ov5647  J2 / i2c-2 / 0x36  树莓派模组"
    exit 1
}

[ -n "$MODE" ] || usage

stop_all() {
    /root/stop_security.sh 2>/dev/null || true
    if [ -x /root/stream/stop_rtsp.sh ]; then
        sh /root/stream/stop_rtsp.sh 2>/dev/null || true
    fi
    [ -f "$PIDF" ] && kill "$(cat "$PIDF")" 2>/dev/null || true
    rm -f "$PIDF"
    for _p in $(ps | grep rtsp_server | grep -v grep | awk '{print $1}'); do
        kill "$_p" 2>/dev/null || true
    done
    rmmod debris 2>/dev/null || true
    sleep 2
}

case "$MODE" in
    gc2083|2083|j1)
        LABEL="GC2083 J1"
        INI=/mnt/data/sensor_cfg_GC2083.ini
        BIN=cvi_sdr_bin_GC2083
        I2C_BUS=3
        I2C_ADDR=37
        INIT_PAT="GC2083"
        MISMATCH_OK=1
        ;;
    ov5647|5647|j2)
        LABEL="OV5647 J2"
        INI=/mnt/data/sensor_cfg_OV5647_J2.ini
        BIN=cvi_sdr_bin_OV5647.bin
        I2C_BUS=2
        I2C_ADDR=36
        INIT_PAT="OV5647"
        MISMATCH_OK=0
        ;;
    *)
        usage
        ;;
esac

[ -f "$INI" ] || { echo "FAIL: missing $INI"; exit 1; }
[ -f "$PARAM/$BIN" ] || { echo "FAIL: missing $PARAM/$BIN"; exit 1; }

echo "=========================================="
echo " 单摄调通: $LABEL"
echo "=========================================="

stop_all
echo "[1/6] stopped rtsp + debris"

ln -sf "$INI" /mnt/data/sensor_cfg.ini
ln -sf "$BIN" "$PARAM/cvi_sdr_bin"
echo "[2/6] config:"
ls -la /mnt/data/sensor_cfg.ini "$PARAM/cvi_sdr_bin"
grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini

DEVNUM=$(grep -E '^[[:space:]]*dev_num' /mnt/data/sensor_cfg.ini | sed 's/[^0-9]//g')
if [ "$DEVNUM" != "1" ]; then
    echo "FAIL: dev_num=$DEVNUM (need 1)"
    exit 1
fi
echo "[3/6] dev_num=1 OK"

echo "[4/6] I2C scan bus $I2C_BUS (expect 0x$(printf '%02x' "$I2C_ADDR")):"
i2cdetect -y "$I2C_BUS" 2>/dev/null | grep -E "30:|--" || i2cdetect -y "$I2C_BUS" 2>/dev/null | tail -3

export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
: > "$LOG"
/root/stream/start_rtsp.sh /root/stream/cam0.json
sleep 16
echo "[5/6] rtsp started"

FAIL=0
if ! kill -0 "$(cat "$PIDF")" 2>/dev/null; then
    echo "FAIL: rtsp_server not running"
    tail -25 "$LOG"
    exit 1
fi
echo "      pid $(cat "$PIDF") alive"

if ! netstat -ln 2>/dev/null | grep -q ':8554'; then
    echo "WARN: port 8554 not listening yet"
    FAIL=1
fi

if ! grep -q "$INIT_PAT" "$LOG" 2>/dev/null || ! grep -qi "Init OK" "$LOG"; then
    echo "FAIL: no $INIT_PAT Init OK in log"
    FAIL=1
fi

if grep -qi mismatch "$LOG"; then
    if [ "$MISMATCH_OK" = 1 ]; then
        echo "NOTE: mismatch present (GC2083 常见，阶段 B 可有画面)"
    else
        echo "FAIL: mismatch (OV5647 应链 cvi_sdr_bin_OV5647.bin)"
        FAIL=1
    fi
fi

echo "[6/6] log summary:"
grep -iE 'sensor =|Init OK|mismatch|vi init|fail|error|ISP Dev' "$LOG" | tail -12 || true

echo ""
echo "=========================================="
if [ "$FAIL" = 0 ]; then
    echo " 板上检查: PASS — 请在 Mac 验证画面"
else
    echo " 板上检查: FAIL — 看上方日志；可 reboot 后重跑"
fi
echo "=========================================="
echo "Mac:"
echo "  ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0"
echo "  ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 10 ${MODE}_test.mp4"
echo "  ffprobe -show_entries stream=bit_rate -of default=nw=1 ${MODE}_test.mp4"
echo ""
echo "码率参考: gc2083 ~1.7Mbps  ov5647 ~4Mbps  黑屏常 <100kbps"
echo "下一颗: $0 $([ "$MODE" = gc2083 ] && echo ov5647 || echo gc2083)"

exit "$FAIL"
