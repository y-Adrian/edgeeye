#!/bin/sh
# test_my_cam_test_phase4.sh — 阶段 4 验收：VPSS → VENC 写 H.264
#
# 用法：./test_my_cam_test_phase4.sh [gc2083|ov5647]
set -e

SENSOR="${1:-gc2083}"
BIN="${MY_CAM_TEST:-/root/my_cam_test}"
OUT="${H264_OUT:-/tmp/frame.h264}"

case "$SENSOR" in
    gc2083|GC2083|j1|J1)
        INI=/mnt/data/sensor_cfg_GC2083.ini
        PQ=cvi_sdr_bin_GC2083
        ;;
    ov5647|OV5647|j2|J2)
        INI=/mnt/data/sensor_cfg_OV5647_J2.ini
        PQ=cvi_sdr_bin_OV5647.bin
        ;;
    *)
        echo "usage: $0 [gc2083|ov5647]"
        exit 1
        ;;
esac

if [ ! -x "$BIN" ]; then
    echo "missing $BIN"
    exit 1
fi

echo "=== test_my_cam_test phase 4: $SENSOR ==="

for p in $(ps | grep -E 'sample_vi|rtsp_server|my_cam_test|camera-test' | grep -v grep | awk '{print $1}'); do
    kill "$p" 2>/dev/null || true
done
sleep 2
rmmod debris 2>/dev/null || true

ln -sf "$INI" /mnt/data/sensor_cfg.ini
ln -sf "$PQ" /mnt/cfg/param/cvi_sdr_bin
rm -f "$OUT"

LOG=/tmp/my_cam_test_p4.log
"$BIN" -p 4 -o "$OUT" >"$LOG" 2>&1
cat "$LOG"

grep -q 'saved H264' "$LOG" || { echo "FAIL: no saved H264 line"; exit 1; }
grep -q 'PASSED (phase 4)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }
[ -f "$OUT" ] || { echo "FAIL: missing $OUT"; exit 1; }

BYTES=$(wc -c <"$OUT")
if [ "$BYTES" -lt 1024 ]; then
    echo "FAIL: $OUT too small ($BYTES bytes)"
    exit 1
fi

echo "OK: $OUT size=$BYTES bytes"
echo "Mac preview: scp root@192.168.42.1:$OUT . && ffplay frame.h264"
echo "=== PASSED phase 4 ($SENSOR) ==="
