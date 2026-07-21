#!/bin/sh
# check_ai_grab_frame_board.sh — 板上验证 ai_grab_frame（需 cam0 RTSP）
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"

ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_IP" '
set -e
BIN=/root/ai_grab_frame
[ -x "$BIN" ] || { echo "missing $BIN — build+deploy ai_grab_frame"; exit 1; }
[ -x /mnt/data/bin/ffmpeg ] || command -v ffmpeg >/dev/null || {
	echo "missing ffmpeg"
	exit 1
}

# RTSP 必须在
if [ -f /tmp/edgeeye_cam_rtsp.pid ] && kill -0 "$(cat /tmp/edgeeye_cam_rtsp.pid)" 2>/dev/null; then
	:
elif pgrep -x edgeeye_cam >/dev/null 2>&1; then
	:
else
	echo "edgeeye_cam not running — ./run_edgeeye_stack.sh first"
	exit 1
fi

OUT=/tmp/edgeeye_ai_frame_test.jpg
rm -f "$OUT"
"$BIN" --dry-run
"$BIN" --once --url rtsp://127.0.0.1:8554/cam0 --out "$OUT" --width 448 --height 448
test -f "$OUT"
SZ=$(wc -c < "$OUT")
test "$SZ" -gt 64
# JPEG SOI
dd if="$OUT" bs=1 count=2 2>/dev/null | od -An -tx1 | grep -q "ff d8"
echo "=== frame bytes=$SZ ==="
ls -la "$OUT"
echo "=== ai_grab_frame board OK ==="
'
