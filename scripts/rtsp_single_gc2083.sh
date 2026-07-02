#!/bin/sh
# rtsp_single_gc2083.sh — J1 GC2083 快速预览（转发至已验证 554 路径）
#
# 历史：曾用 rtsp_server @8554/cam0；ISSUE-002 已证无画面。
# 现统一走 preview_gc2083_554.sh（camera-test / sample_vi_fd）。
set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ -x "$SCRIPT_DIR/preview_gc2083_554.sh" ]; then
    exec sh "$SCRIPT_DIR/preview_gc2083_554.sh"
fi

if [ -x /root/preview_gc2083_554.sh ]; then
    exec sh /root/preview_gc2083_554.sh
fi

echo "rtsp_single_gc2083: preview_gc2083_554.sh not found"
echo "See docs/CAMERA_BRINGUP_ARCHIVE.md"
exit 1
