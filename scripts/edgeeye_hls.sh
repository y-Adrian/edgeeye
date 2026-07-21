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

if ! "$FFMPEG" -hide_banner -muxers 2>/dev/null | grep -qE '[[:space:]]hls[[:space:]]'; then
	echo "edgeeye_hls: ffmpeg lacks HLS muxer — rebuild with build_ffmpeg_cli.sh" | tee -a "$LOG"
	exit 1
fi

mkdir -p "$HLS_DIR"
umask 022
: >"$LOG"

edgeeye_stop_hls

start_one() {
	tag="$1"
	url="rtsp://127.0.0.1:${EDGEEYE_PORT}/${tag}"
	pidfile="/tmp/edgeeye_hls_${tag}.pid"
	playlist="$HLS_DIR/${tag}.m3u8"
	seg="$HLS_DIR/${tag}_%03d.ts"

	rm -f "$HLS_DIR/${tag}"*.ts "$playlist" 2>/dev/null || true

	# -c copy + h264_mp4toannexb：CVI RTSP 码流常需转 Annex-B 才能切 TS/HLS
	# 勿用 nobuffer/low_delay：易卡在等关键帧，目录一直空但进程还活着
	nohup "$FFMPEG" -y -loglevel warning -rtsp_transport tcp \
		-analyzeduration 2000000 -probesize 1000000 \
		-i "$url" -an -c:v copy -bsf:v h264_mp4toannexb \
		-f hls \
		-hls_time 2 \
		-hls_list_size 5 \
		-hls_flags delete_segments+append_list+omit_endlist+independent_segments \
		-hls_segment_filename "$seg" \
		"$playlist" >>"$LOG" 2>&1 &
	echo $! >"$pidfile"
	echo "edgeeye_hls: started $tag pid=$(cat "$pidfile") -> $playlist" | tee -a "$LOG"
}

# HLS 文件默认可能 600，放宽读权限供 http.server 访问
chmod_hls_dir() {
	chmod a+rX "$HLS_DIR" 2>/dev/null || true
	chmod a+r "$HLS_DIR"/cam*.m3u8 "$HLS_DIR"/cam*.ts 2>/dev/null || true
}

wait_playlist() {
	tag="$1"
	playlist="$HLS_DIR/${tag}.m3u8"
	pidfile="/tmp/edgeeye_hls_${tag}.pid"
	i=0
	while [ "$i" -lt 25 ]; do
		if [ -s "$playlist" ]; then
			chmod_hls_dir
			echo "edgeeye_hls: $tag playlist ok ($(wc -c <"$playlist") bytes)" | tee -a "$LOG"
			return 0
		fi
		if [ -f "$pidfile" ] && ! kill -0 "$(cat "$pidfile")" 2>/dev/null; then
			echo "edgeeye_hls: $tag ffmpeg exited before playlist" | tee -a "$LOG"
			return 1
		fi
		sleep 1
		i=$((i + 1))
	done
	echo "edgeeye_hls: WARN $tag no playlist after 25s (see $LOG)" | tee -a "$LOG"
	return 1
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
wait_playlist cam0 || true
if [ "$EDGEEYE_MODE" = "dual" ]; then
	# cam1 错开，减轻双路同时拉 RTSP
	sleep 2
	start_one cam1 || echo "WARN: cam1 HLS failed (preview cam0 only)" | tee -a "$LOG"
	wait_playlist cam1 || true
fi

echo "edgeeye_hls: ready dir=$HLS_DIR"
ls -la "$HLS_DIR" >>"$LOG" 2>/dev/null || true
