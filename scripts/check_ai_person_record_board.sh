#!/bin/sh
# check_ai_person_record_board.sh — 人检测触发录像验收
#
# 1) 真实检测：有人则走 detect→record
# 2) 无人时：--simulate-person --record 验证「触发录像」通路
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
CLIP_SEC="${CLIP_SEC:-8}"

ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_IP" "
set -e
export LD_LIBRARY_PATH=/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd
export FFMPEG=/mnt/data/bin/ffmpeg

[ -x /root/ai_person_detect.sh ] || { echo missing ai_person_detect.sh; exit 1; }
[ -x /root/record_clip.sh ] || [ -x /mnt/data/bin/ffmpeg ] || {
	echo missing record_clip/ffmpeg; exit 1
}

if [ -f /tmp/edgeeye_cam_rtsp.pid ] && kill -0 \"\$(cat /tmp/edgeeye_cam_rtsp.pid)\" 2>/dev/null; then
	:
elif pgrep -x edgeeye_cam >/dev/null 2>&1; then
	:
else
	echo 'edgeeye_cam not running'
	exit 1
fi

/root/ai_person_detect.sh --dry-run --frame-source rtsp --record --clip-sec ${CLIP_SEC}

CDIR=/tmp/edgeeye_ai_clips_test
EDIR=/tmp/edgeeye_ai_rec_events
rm -rf \"\$CDIR\" \"\$EDIR\"
mkdir -p \"\$CDIR\"

# 先真实检测
/root/ai_person_detect.sh --once --frame-source rtsp --record --clip-sec ${CLIP_SEC} \
	--clip-dir \"\$CDIR\" --log-dir \"\$EDIR\" || true

OBJ=0
if [ -f /tmp/edgeeye_ai_det.log ]; then
	OBJ=\$(grep -E '^objnum: ' /tmp/edgeeye_ai_det.log | tail -1 | awk '{print \$2}')
	[ -n \"\$OBJ\" ] || OBJ=0
fi
echo CHECK real_objnum=\$OBJ

if [ \"\$OBJ\" -gt 0 ] 2>/dev/null; then
	test -f \"\$EDIR/events.ndjson\"
	grep -q '\"source\":\"detect\"' \"\$EDIR/events.ndjson\"
	N=\$(ls \"\$CDIR\"/*.mp4 2>/dev/null | wc -l)
	test \"\$N\" -ge 1
	SZ=\$(ls -l \"\$CDIR\"/*.mp4 | awk '{print \$5}' | head -1)
	test \"\$SZ\" -gt 1000
	echo \"=== AI detect→record OK bytes=\$SZ ===\"
	ls -la \"\$CDIR\"
	echo '=== ai_person_record board OK ==='
	exit 0
fi

echo 'no person in frame — verify record trigger via --simulate-person'
rm -rf \"\$CDIR\" \"\$EDIR\"
mkdir -p \"\$CDIR\"
/root/ai_person_detect.sh --once --simulate-person --record --clip-sec ${CLIP_SEC} \
	--clip-dir \"\$CDIR\" --log-dir \"\$EDIR\"
test -f \"\$EDIR/events.ndjson\"
grep -q '\"source\":\"simulate\"' \"\$EDIR/events.ndjson\"
N=\$(ls \"\$CDIR\"/*.mp4 2>/dev/null | wc -l)
test \"\$N\" -ge 1
SZ=\$(ls -l \"\$CDIR\"/*.mp4 | awk '{print \$5}' | head -1)
test \"\$SZ\" -gt 1000
echo \"=== simulate→record OK bytes=\$SZ ===\"
ls -la \"\$CDIR\"
tail -1 \"\$EDIR/events.ndjson\"
echo '=== ai_person_record board OK ==='
"
