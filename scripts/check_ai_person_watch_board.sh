#!/bin/sh
# check_ai_person_watch_board.sh — 循环人检 + cooldown 验收
#
# 1) dry-run 含 watch/interval/cooldown
# 2) --watch --max-rounds 2（真实取帧，可无人）
# 3) --watch --max-rounds 1 --simulate-person --cooldown（验触发+冷却字段）
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"

ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_IP" '
set -e
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
export FFMPEG=/mnt/data/bin/ffmpeg

[ -x /root/ai_person_detect.sh ] || { echo missing ai_person_detect.sh; exit 1; }

if [ -f /tmp/edgeeye_cam_rtsp.pid ] && kill -0 "$(cat /tmp/edgeeye_cam_rtsp.pid)" 2>/dev/null; then
	:
elif pgrep -x edgeeye_cam >/dev/null 2>&1; then
	:
else
	echo "edgeeye_cam not running"
	exit 1
fi

/root/ai_person_detect.sh --dry-run --frame-source rtsp --watch --interval 2 --cooldown 3 --record

echo "=== watch empty rounds ==="
/root/ai_person_detect.sh --watch --frame-source rtsp --max-rounds 2 --interval 1
grep -q "max-rounds=2 reached" /tmp/edgeeye_stack.log 2>/dev/null || true

EDIR=/tmp/edgeeye_ai_watch_events
rm -rf "$EDIR"
mkdir -p "$EDIR"

echo "=== watch simulate one hit + cooldown ==="
# cooldown=2：命中后应 sleep；max-rounds=1 在 sleep 前不会进第二轮
OUT=$(/root/ai_person_detect.sh --watch --max-rounds 1 --simulate-person \
	--interval 1 --cooldown 2 --log-dir "$EDIR" 2>&1)
echo "$OUT"
echo "$OUT" | grep -q "watch start"
echo "$OUT" | grep -q "SIMULATE person"
echo "$OUT" | grep -q "cooldown 2s"
echo "$OUT" | grep -q "max-rounds=1 reached"
test -f "$EDIR/events.ndjson"
grep -q "\"source\":\"simulate\"" "$EDIR/events.ndjson"
tail -1 "$EDIR/events.ndjson"

echo "=== ai_person_watch board OK ==="
'
