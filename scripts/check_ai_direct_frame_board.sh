#!/bin/sh
# check_ai_direct_frame_board.sh — VPSS 直取 AI 帧板上验收
#
# 测试接口：edgeeye_cam --ai-direct；ai_grab_frame --source vpss
# 测试场景：单摄 RTSP 持续运行时按请求导出 NV12，再转 448×448 JPEG
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"

ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_IP" '
set -e
cd /root

[ -x ./edgeeye_cam ] || { echo "missing edgeeye_cam"; exit 1; }
[ -x ./ai_grab_frame ] || { echo "missing ai_grab_frame"; exit 1; }
[ -x ./start_my_cam_rtsp.sh ] || { echo "missing start_my_cam_rtsp.sh"; exit 1; }

./stop_edgeeye_stack.sh 2>/dev/null || true
./start_my_cam_rtsp.sh gc2083 --res 720p --ai-direct

ps w | grep '[e]dgeeye_cam.*--ai-direct' >/dev/null

OUT=/tmp/edgeeye_ai_direct_test.jpg
rm -f "$OUT" /tmp/edgeeye_ai_frame.nv12 /tmp/edgeeye_ai_frame.meta
./ai_grab_frame --dry-run --source vpss
./ai_grab_frame --once --source vpss --out "$OUT" --width 448 --height 448

test -s /tmp/edgeeye_ai_frame.nv12
test -s /tmp/edgeeye_ai_frame.meta
test -s "$OUT"
SZ=$(wc -c < "$OUT")
test "$SZ" -gt 64
dd if="$OUT" bs=1 count=2 2>/dev/null | od -An -tx1 | grep -q "ff d8"
echo "=== direct frame bytes=$SZ meta=$(cat /tmp/edgeeye_ai_frame.meta) ==="
ls -la "$OUT" /tmp/edgeeye_ai_frame.nv12
echo "=== ai_direct_frame board OK ==="
'
