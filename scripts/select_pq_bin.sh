#!/bin/sh
# select_pq_bin.sh — 按摄像头型号切换 /mnt/cfg/param/cvi_sdr_bin 软链
#
# ISP 只读 cvi_sdr_bin；用错 bin 会 mismatch + 黑屏（OV5647 用 GC2083 bin 时）。
# 板上文件（SDK overlay）：cvi_sdr_bin_GC2083、cvi_sdr_bin_OV5647.bin、cvi_sdr_bin_SC035HGS
#
# 用法：
#   ./select_pq_bin.sh ov5647   # J2 树莓派头
#   ./select_pq_bin.sh gc2083   # J1 官方头
#   ./select_pq_bin.sh status
set -e

PARAM="${PQ_PARAM_DIR:-/mnt/cfg/param}"
LINK="$PARAM/cvi_sdr_bin"

usage() {
    echo "usage: $0 ov5647|gc2083|status"
    echo "  ov5647  -> cvi_sdr_bin_OV5647.bin (sensor id 22087)"
    echo "  gc2083  -> cvi_sdr_bin_GC2083 (sensor id 2053/2083 family)"
    exit 1
}

[ -d "$PARAM" ] || { echo "missing $PARAM"; exit 1; }

case "${1:-}" in
    ov5647|OV5647|5647|j2|J2)
        TARGET="cvi_sdr_bin_OV5647.bin"
        ;;
    gc2083|GC2083|2083|j1|J1)
        TARGET="cvi_sdr_bin_GC2083"
        ;;
    status)
        ls -la "$PARAM"/cvi_sdr_bin* 2>/dev/null || true
        exit 0
        ;;
    *)
        usage
        ;;
esac

[ -f "$PARAM/$TARGET" ] || [ -L "$PARAM/$TARGET" ] || {
    echo "missing $PARAM/$TARGET"
    exit 1
}

ln -sf "$TARGET" "$LINK"
echo "cvi_sdr_bin -> $TARGET"
ls -la "$LINK"
