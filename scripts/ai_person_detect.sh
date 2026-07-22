#!/bin/sh
# ai_person_detect.sh — 取帧 + MobileDet 行人检测 + 本地日志 + 可选录像
#
# 依赖（板上）：
#   /root/ai_grab_frame  /root/ai_event_log  /root/record_clip.sh
#   /mnt/system/usr/bin/ai/sample_img_det
#   /mnt/cvimodel/mobiledetv2-pedestrian-d0-ls-448.cvimodel
#   /mnt/system/lib/libcvi_tdl_app.so
#
# 用法：
#   ./ai_person_detect.sh --dry-run
#   ./ai_person_detect.sh --once
#   ./ai_person_detect.sh --once --record --clip-sec 15
#   ./ai_person_detect.sh --watch --interval 20 --cooldown 60 --frame-source vpss
#   ./ai_person_detect.sh --watch --max-rounds 2 --interval 1
#   ./ai_person_detect.sh --once --simulate-person --record
set -e

BOARD_DIR="${BOARD_DIR:-/root}"
GRAB="${BOARD_DIR}/ai_grab_frame"
LOGBIN="${BOARD_DIR}/ai_event_log"
RECORD_SH="${BOARD_DIR}/record_clip.sh"
SAMPLE="${SAMPLE_IMG_DET:-/mnt/system/usr/bin/ai/sample_img_det}"
MODEL_NAME="mobiledetv2-pedestrian"
MODEL_PATH="${AI_MODEL_PATH:-/mnt/cvimodel/mobiledetv2-pedestrian-d0-ls-448.cvimodel}"
FRAME="${AI_FRAME_PATH:-/tmp/edgeeye_ai_frame.jpg}"
FRAME_SOURCE="${AI_FRAME_SOURCE:-vpss}"
LOG_DIR="${AI_LOG_DIR:-}"
URL="${AI_RTSP_URL:-rtsp://127.0.0.1:8554/cam0}"
WIDTH="${AI_FRAME_W:-448}"
HEIGHT="${AI_FRAME_H:-448}"
CLIP_SEC="${AI_CLIP_SEC:-15}"
CLIP_DIR="${CLIP_DIR:-}"
INTERVAL="${AI_INTERVAL_SEC:-20}"
COOLDOWN="${AI_COOLDOWN_SEC:-60}"
MAX_ROUNDS=0
DRY=0
ONCE=0
WATCH=0
DO_RECORD=0
SIMULATE=0

export LD_LIBRARY_PATH="/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:${LD_LIBRARY_PATH:-}"

usage() {
	sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
}

resolve_clip_dir() {
	if [ -n "$CLIP_DIR" ]; then
		printf '%s' "$CLIP_DIR"
		return 0
	fi
	if [ -d /mnt/sd ] && [ -w /mnt/sd ]; then
		printf '%s' "/mnt/sd/clips"
	else
		printf '%s' "/mnt/data/clips"
	fi
}

while [ $# -gt 0 ]; do
	case "$1" in
	--dry-run) DRY=1; shift ;;
	--once) ONCE=1; shift ;;
	--watch) WATCH=1; shift ;;
	--record) DO_RECORD=1; shift ;;
	--simulate-person) SIMULATE=1; shift ;;
	--clip-sec) CLIP_SEC="$2"; shift 2 ;;
	--clip-dir) CLIP_DIR="$2"; shift 2 ;;
	--log-dir) LOG_DIR="$2"; shift 2 ;;
	--url) URL="$2"; shift 2 ;;
	--frame) FRAME="$2"; shift 2 ;;
	--frame-source) FRAME_SOURCE="$2"; shift 2 ;;
	--model) MODEL_PATH="$2"; shift 2 ;;
	--interval) INTERVAL="$2"; shift 2 ;;
	--cooldown) COOLDOWN="$2"; shift 2 ;;
	--max-rounds) MAX_ROUNDS="$2"; shift 2 ;;
	-h|--help) usage ;;
	*) echo "unknown: $1" >&2; usage ;;
	esac
done

case "$FRAME_SOURCE" in
vpss|rtsp) ;;
*) echo "invalid frame source: $FRAME_SOURCE (use vpss|rtsp)" >&2; exit 1 ;;
esac

if [ "$DRY" = "1" ]; then
	echo "ai_person_detect dry-run"
	echo "  grab=$GRAB"
	echo "  sample=$SAMPLE"
	echo "  model=$MODEL_PATH"
	echo "  frame=$FRAME"
	echo "  frame_source=$FRAME_SOURCE"
	echo "  url=$URL"
	echo "  record=$DO_RECORD clip_sec=$CLIP_SEC clip_dir=$(resolve_clip_dir)"
	echo "  watch=$WATCH interval=$INTERVAL cooldown=$COOLDOWN max_rounds=$MAX_ROUNDS"
	[ -x "$GRAB" ] || { echo "missing $GRAB"; exit 1; }
	[ -x "$LOGBIN" ] || { echo "missing $LOGBIN"; exit 1; }
	[ -x "$SAMPLE" ] || { echo "missing $SAMPLE"; exit 1; }
	[ -f "$MODEL_PATH" ] || { echo "missing model $MODEL_PATH"; exit 1; }
	[ -f /mnt/system/lib/libcvi_tdl_app.so ] || \
		echo "WARN: missing libcvi_tdl_app.so — run install_tdl_libs_board.sh"
	if [ "$DO_RECORD" = "1" ]; then
		[ -x "$RECORD_SH" ] || [ -x /mnt/data/bin/ffmpeg ] || \
			echo "WARN: record_clip.sh / ffmpeg may be missing"
	fi
	echo "  deps ok"
	exit 0
fi

[ "$ONCE" = "1" ] || [ "$WATCH" = "1" ] || usage

[ -x "$GRAB" ] || { echo "missing $GRAB"; exit 1; }

write_event_and_maybe_record() {
	_score="$1"
	_source="$2"
	echo "ai_person_detect: person score=$_score source=$_source — write event log"
	if [ -x "$LOGBIN" ]; then
		if [ -n "$LOG_DIR" ]; then
			"$LOGBIN" --inject person --score "$_score" --cam cam0 --source "$_source" --log-dir "$LOG_DIR"
		else
			"$LOGBIN" --inject person --score "$_score" --cam cam0 --source "$_source"
		fi
	else
		echo "WARN: no ai_event_log binary"
	fi

	if [ "$DO_RECORD" = "1" ]; then
		CDIR=$(resolve_clip_dir)
		mkdir -p "$CDIR" 2>/dev/null || true
		export CLIP_DIR="$CDIR"
		export RTSP_PORT=8554
		if [ -x /mnt/data/bin/ffmpeg ]; then
			export FFMPEG=/mnt/data/bin/ffmpeg
		fi
		if [ -x "$RECORD_SH" ]; then
			echo "ai_person_detect: record ${CLIP_SEC}s -> $CDIR"
			sh "$RECORD_SH" "$CLIP_SEC" cam0
		elif [ -x /mnt/data/bin/ffmpeg ]; then
			OUT="$CDIR/$(date +%s)_cam0_ai.mp4"
			echo "ai_person_detect: ffmpeg record -> $OUT"
			/mnt/data/bin/ffmpeg -y -loglevel warning -rtsp_transport tcp \
				-i "$URL" -c copy -t "$CLIP_SEC" "$OUT"
			echo "saved: $OUT"
		else
			echo "WARN: cannot record — no record_clip.sh / ffmpeg"
			return 1
		fi
	fi
	return 0
}

# HIT=1 时已写事件/录像；HIT=0 无人；非 0 返回码表示检测失败
run_one_round() {
	HIT=0
	if [ "$SIMULATE" = "1" ]; then
		echo "ai_person_detect: SIMULATE person (skip model)"
		write_event_and_maybe_record "0.9000" "simulate" || return 1
		HIT=1
		# 循环里只模拟首轮，避免一直假阳性
		SIMULATE=0
		return 0
	fi

	[ -x "$SAMPLE" ] || { echo "missing $SAMPLE"; return 1; }
	[ -f "$MODEL_PATH" ] || { echo "missing $MODEL_PATH"; return 1; }

	echo "ai_person_detect: grab source=$FRAME_SOURCE -> $FRAME (${WIDTH}x${HEIGHT})"
	"$GRAB" --once --source "$FRAME_SOURCE" --url "$URL" --out "$FRAME" \
		--width "$WIDTH" --height "$HEIGHT"

	echo "ai_person_detect: run $SAMPLE"
	DET_LOG=/tmp/edgeeye_ai_det.log
	set +e
	"$SAMPLE" "$MODEL_NAME" "$MODEL_PATH" "$FRAME" >"$DET_LOG" 2>&1
	DET_RC=$?
	set -e
	grep -vE '^(found not named|parse |minlevel:)' "$DET_LOG" || cat "$DET_LOG"

	OBJNUM=$(grep -E '^objnum: ' "$DET_LOG" | tail -1 | awk '{print $2}')
	[ -n "$OBJNUM" ] || OBJNUM=0

	echo "ai_person_detect: objnum=$OBJNUM rc=$DET_RC"

	if [ "$DET_RC" -ne 0 ]; then
		echo "ai_person_detect: detection failed"
		return "$DET_RC"
	fi

	if [ "$OBJNUM" -gt 0 ] 2>/dev/null; then
		SCORE=$(grep -E '^boxes=' "$DET_LOG" | tail -1 | sed 's/^boxes=//' | tr -d '[]' | \
			awk -F',' '{
				max=0
				for (i=6; i<=NF; i+=6) {
					s=$i+0
					if (s>max) max=s
				}
				if (max<=0) max=0.5
				printf "%.4f", max
			}')
		[ -n "$SCORE" ] || SCORE="0.5000"
		write_event_and_maybe_record "$SCORE" "detect" || return 1
		HIT=1
	else
		echo "ai_person_detect: no person in frame (no event/record)"
		HIT=0
	fi
	return 0
}

if [ "$ONCE" = "1" ]; then
	run_one_round
	exit $?
fi

# --watch
ROUND=0
echo "ai_person_detect: watch start interval=${INTERVAL}s cooldown=${COOLDOWN}s record=$DO_RECORD max_rounds=$MAX_ROUNDS"
while true; do
	ROUND=$((ROUND + 1))
	echo "ai_person_detect: ---- round $ROUND ----"
	if ! run_one_round; then
		echo "ai_person_detect: round failed, sleep ${INTERVAL}s then retry"
		sleep "$INTERVAL"
	elif [ "$HIT" = "1" ]; then
		echo "ai_person_detect: hit — cooldown ${COOLDOWN}s"
		sleep "$COOLDOWN"
	else
		sleep "$INTERVAL"
	fi

	if [ "$MAX_ROUNDS" -gt 0 ] 2>/dev/null && [ "$ROUND" -ge "$MAX_ROUNDS" ]; then
		echo "ai_person_detect: max-rounds=$MAX_ROUNDS reached, exit"
		exit 0
	fi
done
