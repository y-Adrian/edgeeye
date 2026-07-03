#!/bin/sh
# capture_dual_init_log.sh — 抓取 vendor 双摄 rtsp_server 初始化日志
#
# 用法（板上）：
#   ./capture_dual_init_log.sh [输出路径]
# 默认：/tmp/dual_init_vendor.log
set -e

OUT="${1:-/tmp/dual_init_vendor.log}"
RTSP_BIN="${RTSP_BIN:-/mnt/system/usr/test/rtsp_server}"
CFG="${CFG:-/root/stream/cam_dual.json}"
DUAL_INI=/mnt/data/sensor_cfg_GC2083_OV5647_dual.ini

export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:${LD_LIBRARY_PATH}

stop_all() {
	ps | grep -v grep | grep -v capture_dual_init | \
		grep -E '/my_cam_test[[:space:]]|rtsp_server|sample_vi|camera-test' | \
		awk '{print $1}' | while read -r p; do
			[ -n "$p" ] || continue
			kill "$p" 2>/dev/null || true
		done
	if [ -f /tmp/rtsp_server.pid ]; then
		kill "$(cat /tmp/rtsp_server.pid)" 2>/dev/null || true
		rm -f /tmp/rtsp_server.pid
	fi
	sleep 2
	rmmod debris 2>/dev/null || true
}

if [ ! -x "$RTSP_BIN" ]; then
	echo "missing $RTSP_BIN"
	exit 1
fi
if [ ! -f "$CFG" ]; then
	echo "missing $CFG — deploy output/stream/"
	exit 1
fi

stop_all

rm -f /tmp/*.yuv /tmp/*.h264 2>/dev/null || true

if [ ! -f "$DUAL_INI" ] && [ -f /root/stream/sensor_cfg_GC2083_OV5647_dual.ini ]; then
	cp /root/stream/sensor_cfg_GC2083_OV5647_dual.ini "$DUAL_INI"
fi
if [ ! -f "$DUAL_INI" ]; then
	echo "missing $DUAL_INI"
	exit 1
fi

ln -sf "$DUAL_INI" /mnt/data/sensor_cfg.ini
ln -sf cvi_sdr_bin_GC2083 /mnt/cfg/param/cvi_sdr_bin

{
	echo "=== dual init capture $(date -Iseconds 2>/dev/null || date) ==="
	echo "RTSP_BIN=$RTSP_BIN"
	echo "CFG=$CFG"
	echo "sensor_cfg -> $(readlink -f /mnt/data/sensor_cfg.ini 2>/dev/null || readlink /mnt/data/sensor_cfg.ini)"
	echo "cvi_sdr_bin -> $(readlink /mnt/cfg/param/cvi_sdr_bin)"
	echo "--- sensor_cfg ---"
	grep -E 'dev_num|name|bus_id|mipi' /mnt/data/sensor_cfg.ini || true
	echo "--- cam_dual.json ---"
	cat "$CFG"
	echo "--- rtsp_server log ---"
} >"$OUT"

"$RTSP_BIN" "$CFG" >>"$OUT" 2>&1 &
PID=$!
echo "$PID" > /tmp/rtsp_server.pid

sleep 20

if kill -0 "$PID" 2>/dev/null; then
	echo "--- process alive pid=$PID ---" >>"$OUT"
	netstat -ln 2>/dev/null | grep 8554 >>"$OUT" || ss -ln 2>/dev/null | grep 8554 >>"$OUT" || true
else
	echo "--- process EXITED ---" >>"$OUT"
fi

{
	echo "--- key lines ---"
	grep -iE 'dev_num|devNum|GC2083|OV5647|Init OK|VPSS|VIVPSS|VPSS_MODE|ISP Dev|rtspURL|sensorName|mismatch|error|fail|bind|pipe|grp' "$OUT" || true
} >>"$OUT"

echo "saved: $OUT ($(wc -l <"$OUT") lines)"
echo "preview key lines:"
grep -iE 'dev_num|devNum|GC2083|OV5647|Init OK|VPSS|VIVPSS|ISP Dev|rtspURL|sensorName|mismatch' "$OUT" | tail -40
