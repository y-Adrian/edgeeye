#!/bin/sh
# check_ai_person_detect_board.sh — 板上验证人检测一次通路
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"

ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_IP" '
set -e
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd

[ -x /root/ai_person_detect.sh ] || { echo "missing /root/ai_person_detect.sh"; exit 1; }
[ -x /root/ai_grab_frame ] || { echo "missing ai_grab_frame"; exit 1; }
[ -x /root/ai_event_log ] || { echo "missing ai_event_log"; exit 1; }
[ -f /mnt/system/lib/libcvi_tdl_app.so ] || {
	echo "missing libcvi_tdl_app.so — run ./scripts/install_tdl_libs_board.sh on host"
	exit 1
}
[ -f /mnt/cvimodel/mobiledetv2-pedestrian-d0-ls-448.cvimodel ] || {
	echo "missing pedestrian cvimodel"
	exit 1
}

# cam must be up for grab
if [ -f /tmp/edgeeye_cam_rtsp.pid ] && kill -0 "$(cat /tmp/edgeeye_cam_rtsp.pid)" 2>/dev/null; then
	:
elif pgrep -x edgeeye_cam >/dev/null 2>&1; then
	:
else
	echo "edgeeye_cam not running — start stack first"
	exit 1
fi

/root/ai_person_detect.sh --dry-run
LOGDIR=/tmp/edgeeye_ai_det_events
rm -rf "$LOGDIR"
# 检测通路：即使画面无人，sample 须成功；有人则写日志
/root/ai_person_detect.sh --once --log-dir "$LOGDIR"
test -f /tmp/edgeeye_ai_det.log
grep -qE "^objnum: " /tmp/edgeeye_ai_det.log
OBJ=$(grep -E "^objnum: " /tmp/edgeeye_ai_det.log | tail -1 | awk "{print \$2}")
echo "CHECK objnum=$OBJ"
if [ "$OBJ" -gt 0 ] 2>/dev/null; then
	test -f "$LOGDIR/events.ndjson"
	tail -1 "$LOGDIR/events.ndjson" | grep -q "\"class\":\"person\""
	tail -1 "$LOGDIR/events.ndjson" | grep -q "\"source\":\"detect\""
	echo "=== person event logged ==="
	tail -1 "$LOGDIR/events.ndjson"
else
	echo "=== no person in frame (pipeline OK, no event) ==="
fi
echo "=== ai_person_detect board OK ==="
'
