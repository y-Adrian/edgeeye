#!/bin/sh
# edgeeye_hls.sh — RTSP → HLS remux（-c copy，供浏览器双路直播）
#
# 输出：/root/web/hls/cam{0,1}.m3u8 + 分片
# PID：/tmp/edgeeye_hls_cam0.pid /tmp/edgeeye_hls_cam1.pid
set -e

BOARD_DIR=/root
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh"
edgeeye_load_config

HLS_DIR="${EDGEEYE_HLS_DIR:-$BOARD_DIR/web/hls}"
LOG=/tmp/edgeeye_hls.log
FFMPEG=$(edgeeye_resolve_ffmpeg) || {
	echo "edgeeye_hls: no ffmpeg" | tee -a "$LOG"
	exit 1
}

if ! "$FFMPEG" -hide_banner -muxers 2>/dev/null | grep -q ' hls$'; then
	echo "edgeeye_hls: ffmpeg lacks HLS muxer — rebuild with build_ffmpeg_cli.sh" | tee -a "$LOG"
	exit 1
fi

mkdir -p "$HLS_DIR"
: >"$LOG"

edgeeye_stop_hls

start_one() {
	tag="$1"
	url="rtsp://127.0.0.1:${EDGEEYE_PORT}/${tag}"
	pidfile="/tmp/edgeeye_hls_${tag}.pid"
	playlist="$HLS_DIR/${tag}.m3u8"
	seg="$HLS_DIR/${tag}_%03d.ts"

	rm -f "$HLS_DIR/${tag}"*.ts "$playlist" 2>/dev/null || true

	# -c copy：不解码，降低 C906 负载；短分片降低延迟
	nohup "$FFMPEG" -y -loglevel warning -rtsp_transport tcp \
		-fflags nobuffer -flags low_delay \
		-i "$url" -an -c:v copy \
		-f hls \
		-hls_time 2 \
		-hls_list_size 4 \
		-hls_flags delete_segments+append_list+omit_endlist \
		-hls_segment_filename "$seg" \
		"$playlist" >>"$LOG" 2>&1 &
	echo $! >"$pidfile"
	echo "edgeeye_hls: started $tag pid=$(cat "$pidfile") -> $playlist" | tee -a "$LOG"
}

if [ "$EDGEEYE_MODE" = "dual" ]; then
	if ! edgeeye_wait_rtsp_ready 90; then
		echo "edgeeye_hls: dual RTSP not ready" | tee -a "$LOG"
		exit 1
	fi
elif ! edgeeye_wait_rtsp_ready 60 cam0; then
	echo "edgeeye_hls: RTSP cam0 not ready" | tee -a "$LOG"
	exit 1
fi

start_one cam0
if [ "$EDGEEYE_MODE" = "dual" ]; then
	# cam1 与 cam0 错开 1s，减轻同时建连冲击
	sleep 1
	start_one cam1 || echo "WARN: cam1 HLS failed (preview cam0 only)" | tee -a "$LOG"
fi

echo "edgeeye_hls: ready dir=$HLS_DIR"
