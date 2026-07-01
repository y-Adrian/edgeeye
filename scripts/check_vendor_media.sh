#!/bin/sh
# check_vendor_media.sh — Week 0 / Phase 5A: vendor 媒体栈摸底
#
# 在开发板上运行，检查 CSI/VICAP/VENC 相关模块与 /dev/video* 节点。
# 用法：ssh root@192.168.42.1 'sh -s' < scripts/check_vendor_media.sh
set -e

echo "=== debris camera vendor media check ==="
echo "date: $(date 2>/dev/null || true)"
echo

echo "--- loaded media modules ---"
lsmod | grep -E 'cvi|cv181|mipi|snsr|venc|vi_' || echo "(no matching modules loaded)"
echo

echo "--- /dev/video* ---"
if ls /dev/video* 2>/dev/null; then
    :
else
    echo "(none — start vendor sample or isp pipeline first)"
fi
echo

echo "--- /dev/media* ---"
if ls /dev/media* 2>/dev/null; then
    :
else
    echo "(none)"
fi
echo

echo "--- v4l2-ctl ---"
if command -v v4l2-ctl >/dev/null 2>&1; then
    v4l2-ctl --list-devices 2>&1 || true
else
    echo "v4l2-ctl not installed"
fi
echo

echo "--- media-ctl ---"
if command -v media-ctl >/dev/null 2>&1; then
    media-ctl -p 2>&1 | head -40 || true
else
    echo "media-ctl not installed"
fi
echo

echo "--- I2C sensor (OV5647 @ i2c-2/0x36) ---"
if command -v i2ctransfer >/dev/null 2>&1; then
    id_h=$(i2ctransfer -y 2 w2@0x36 0x30 0x0a r1 2>/dev/null || echo "fail")
    id_l=$(i2ctransfer -y 2 w2@0x36 0x30 0x0b r1 2>/dev/null || echo "fail")
    echo "chip_id bytes: $id_h $id_l (expect 0x56 0x47)"
else
    echo "i2ctransfer not installed"
fi
echo

echo "--- debris driver ---"
if [ -f /proc/debris ]; then
    grep -E 'i2c_ok|sensor_init|camera_count' /proc/debris || cat /proc/debris
else
    echo "/proc/debris not present (insmod debris.ko first)"
fi
echo

echo "=== done ==="
echo "Next: run vendor VI/VENC sample from duo-sdk/cvi_mpi/sample when /dev/video* missing."
