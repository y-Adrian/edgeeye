#!/bin/sh
# test_my_cam_test.sh — 阶段 2 验收：my_cam_test VI/ISP 初始化
#
# 用法：./test_my_cam_test.sh [gc2083|ov5647]
# 默认 gc2083

set -e

SENSOR="${1:-gc2083}"
BIN="${MY_CAM_TEST:-/root/my_cam_test}"
HOLD="${HOLD_SEC:-10}"

case "$SENSOR" in
    gc2083|GC2083|j1|J1)
        INI=/mnt/data/sensor_cfg_GC2083.ini
        PQ=cvi_sdr_bin_GC2083
        PAT=GC2083
        ;;
    ov5647|OV5647|j2|J2)
        INI=/mnt/data/sensor_cfg_OV5647_J2.ini
        PQ=cvi_sdr_bin_OV5647.bin
        PAT=OV5647
        ;;
    *)
        echo "usage: $0 [gc2083|ov5647]"
        exit 1
        ;;
esac

if [ ! -x "$BIN" ]; then
    echo "missing $BIN — run: cd edgeeye-duos && make app && ./deploy"
    exit 1
fi

echo "=== test_my_cam_test: $SENSOR ==="

for p in $(ps | grep -E 'sample_vi|rtsp_server|my_cam_test' | grep -v grep | awk '{print $1}'); do
    kill "$p" 2>/dev/null || true
done
sleep 1

ln -sf "$INI" /mnt/data/sensor_cfg.ini
ln -sf "$PQ" /mnt/cfg/param/cvi_sdr_bin
echo "sensor_cfg -> $(readlink -f /mnt/data/sensor_cfg.ini)"
echo "cvi_sdr_bin -> $(readlink /mnt/cfg/param/cvi_sdr_bin)"

LOG=/tmp/my_cam_test.log
"$BIN" -p 2 -s "$HOLD" >"$LOG" 2>&1
cat "$LOG"

grep -q "$PAT" "$LOG" || { echo "FAIL: no $PAT in log"; exit 1; }
grep -qi 'Init OK' "$LOG" || { echo "FAIL: no Init OK in log"; exit 1; }
grep -q 'PASSED (phase 2)' "$LOG" || { echo "FAIL: no PASSED"; exit 1; }

echo "=== PASSED ($SENSOR) ==="
