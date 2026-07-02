#!/bin/sh
# test_gc2083_rtsp_json.sh — 顺序试 ISSUE-002 新增 JSON 变体（GC2083 + rtsp_server）
#
# 用法（板上）：
#   ./test_gc2083_rtsp_json.sh           # 列出配置，手动 VLC 确认后按 Enter 继续
#   ./test_gc2083_rtsp_json.sh --auto    # 每档停 15s 后自动切下一档（仍须人眼看画面）
#
# 前提：J1 接 GC2083；sensor_cfg.ini 指向 GC2083 单摄 ini；PQ 已链到 GC2083 bin

set -e

STREAM_DIR="${STREAM_DIR:-/root/stream}"
STOP="$STREAM_DIR/stop_rtsp.sh"
START="$STREAM_DIR/start_rtsp.sh"
WAIT_SEC="${WAIT_SEC:-15}"

CFG_LIST="
cam0_gc2083_isp128m.json
cam0_gc2083_compress_none.json
cam0_gc2083_pq_explicit.json
cam0_gc2083_vimode2.json
cam0_gc2083_tuned.json
cam0_gc2083_novpss.json
"

AUTO=0
[ "$1" = "--auto" ] && AUTO=1

if [ ! -x "$START" ]; then
    echo "missing $START"
    exit 1
fi

if ! grep -q GC2083 /mnt/data/sensor_cfg.ini 2>/dev/null; then
    echo "warn: sensor_cfg.ini 可能不是 GC2083，请先："
    echo "  ln -sf /mnt/data/sensor_cfg_GC2083.ini /mnt/data/sensor_cfg.ini"
fi

if [ ! -e /mnt/cfg/param/cvi_sdr_bin ]; then
    echo "warn: /mnt/cfg/param/cvi_sdr_bin 不存在"
fi

IP=$(ip -4 addr show usb0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
[ -z "$IP" ] && IP=192.168.42.1
URL="rtsp://${IP}:8554/cam0"

echo "=== GC2083 rtsp_server JSON 参数扫描 ==="
echo "VLC/ffplay: ffplay -rtsp_transport tcp $URL"
echo "日志: tail -f /tmp/rtsp_server.log"
echo ""

for cfg in $CFG_LIST; do
    path="$STREAM_DIR/$cfg"
    if [ ! -f "$path" ]; then
        echo "skip (missing): $cfg"
        continue
    fi

    echo "----------------------------------------"
    echo ">>> $cfg"
    "$STOP" 2>/dev/null || true
    sleep 1
    "$START" "$path"
    sleep 2
  grep -E 'vi_vpss_mode|bVencBindVpss|bVpssBinding|compress|GC2083|Init OK|fail|error' /tmp/rtsp_server.log | tail -20 || true

    if [ "$AUTO" -eq 1 ]; then
        echo "auto wait ${WAIT_SEC}s ..."
        sleep "$WAIT_SEC"
    else
        printf '有画面? [y=有 / n=黑 / q=退出] '
        read -r ans || ans=n
        case "$ans" in
            y|Y) echo "OK: $cfg" ;;
            q|Q) echo "stopped by user"; exit 0 ;;
            *) echo "NO PICTURE: $cfg" ;;
        esac
    fi
done

echo "=== done ==="
