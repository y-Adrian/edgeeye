#!/bin/sh
# ai_person_detect.sh — 步骤 4：取帧 + MobileDet 行人检测 + 本地事件日志
#
# 依赖（板上）：
#   /root/ai_grab_frame
#   /root/ai_event_log
#   /mnt/system/usr/bin/ai/sample_img_det
#   /mnt/cvimodel/mobiledetv2-pedestrian-d0-ls-448.cvimodel
#   /mnt/system/lib/libcvi_tdl_app.so  （可用 install_tdl_libs_board.sh 部署）
#
# 用法（板上）：
#   ./ai_person_detect.sh --once
#   ./ai_person_detect.sh --once --log-dir /mnt/data/events
#   ./ai_person_detect.sh --dry-run
set -e

BOARD_DIR="${BOARD_DIR:-/root}"
GRAB="${BOARD_DIR}/ai_grab_frame"
LOGBIN="${BOARD_DIR}/ai_event_log"
SAMPLE="${SAMPLE_IMG_DET:-/mnt/system/usr/bin/ai/sample_img_det}"
MODEL_NAME="mobiledetv2-pedestrian"
MODEL_PATH="${AI_MODEL_PATH:-/mnt/cvimodel/mobiledetv2-pedestrian-d0-ls-448.cvimodel}"
FRAME="${AI_FRAME_PATH:-/tmp/edgeeye_ai_frame.jpg}"
LOG_DIR="${AI_LOG_DIR:-}"
URL="${AI_RTSP_URL:-rtsp://127.0.0.1:8554/cam0}"
WIDTH="${AI_FRAME_W:-448}"
HEIGHT="${AI_FRAME_H:-448}"
DRY=0
ONCE=0

export LD_LIBRARY_PATH="/mnt/system/lib:/mnt/system/usr/lib:/mnt/system/usr/lib/3rd:${LD_LIBRARY_PATH:-}"

usage() {
	sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
}

while [ $# -gt 0 ]; do
	case "$1" in
	--dry-run) DRY=1; shift ;;
	--once) ONCE=1; shift ;;
	--log-dir) LOG_DIR="$2"; shift 2 ;;
	--url) URL="$2"; shift 2 ;;
	--frame) FRAME="$2"; shift 2 ;;
	--model) MODEL_PATH="$2"; shift 2 ;;
	-h|--help) usage ;;
	*) echo "unknown: $1" >&2; usage ;;
	esac
done

if [ "$DRY" = "1" ]; then
	echo "ai_person_detect dry-run"
	echo "  grab=$GRAB"
	echo "  sample=$SAMPLE"
	echo "  model=$MODEL_PATH"
	echo "  frame=$FRAME"
	echo "  url=$URL"
	[ -x "$GRAB" ] || { echo "missing $GRAB"; exit 1; }
	[ -x "$LOGBIN" ] || { echo "missing $LOGBIN"; exit 1; }
	[ -x "$SAMPLE" ] || { echo "missing $SAMPLE"; exit 1; }
	[ -f "$MODEL_PATH" ] || { echo "missing model $MODEL_PATH"; exit 1; }
	[ -f /mnt/system/lib/libcvi_tdl_app.so ] || \
		echo "WARN: missing libcvi_tdl_app.so — run install_tdl_libs_board.sh"
	echo "  deps ok"
	exit 0
fi

[ "$ONCE" = "1" ] || usage

[ -x "$GRAB" ] || { echo "missing $GRAB"; exit 1; }
[ -x "$SAMPLE" ] || { echo "missing $SAMPLE"; exit 1; }
[ -f "$MODEL_PATH" ] || { echo "missing $MODEL_PATH"; exit 1; }

echo "ai_person_detect: grab $URL -> $FRAME (${WIDTH}x${HEIGHT})"
"$GRAB" --once --url "$URL" --out "$FRAME" --width "$WIDTH" --height "$HEIGHT"

echo "ai_person_detect: run $SAMPLE"
DET_LOG=/tmp/edgeeye_ai_det.log
set +e
"$SAMPLE" "$MODEL_NAME" "$MODEL_PATH" "$FRAME" >"$DET_LOG" 2>&1
DET_RC=$?
set -e
cat "$DET_LOG"

OBJNUM=$(grep -E '^objnum: ' "$DET_LOG" | tail -1 | awk '{print $2}')
[ -n "$OBJNUM" ] || OBJNUM=0

echo "ai_person_detect: objnum=$OBJNUM rc=$DET_RC"

if [ "$DET_RC" -ne 0 ]; then
	echo "ai_person_detect: detection failed"
	exit "$DET_RC"
fi

if [ "$OBJNUM" -gt 0 ] 2>/dev/null; then
	# 从 boxes 行取最大 score（字段第 6 个）
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
	echo "ai_person_detect: person detected score=$SCORE — write event log"
	if [ -x "$LOGBIN" ]; then
		if [ -n "$LOG_DIR" ]; then
			"$LOGBIN" --inject person --score "$SCORE" --cam cam0 --source detect --log-dir "$LOG_DIR"
		else
			"$LOGBIN" --inject person --score "$SCORE" --cam cam0 --source detect
		fi
	else
		echo "WARN: no ai_event_log binary"
	fi
else
	echo "ai_person_detect: no person in frame (no event written)"
fi

exit 0
