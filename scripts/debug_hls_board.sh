#!/bin/sh
# debug_hls_board.sh — 板上诊断 / 修复 HLS remux（在板子 /root 执行）
set -e

FFMPEG="${FFMPEG:-/mnt/data/bin/ffmpeg}"
HLS_DIR=/root/web/hls
PORT="${PORT:-8554}"

echo "=== ffmpeg ==="
ls -la "$FFMPEG"
"$FFMPEG" -hide_banner -muxers 2>/dev/null | grep -E '[[:space:]]hls[[:space:]]' || {
	echo "FAIL: no hls muxer"
	exit 1
}
"$FFMPEG" -hide_banner -bsfs 2>/dev/null | grep h264_mp4toannexb || \
	echo "WARN: no h264_mp4toannexb bsf"

echo "=== stop old hls ffmpeg ==="
pkill -f '/root/web/hls/' 2>/dev/null || true
pkill -f "web/hls/cam" 2>/dev/null || true
sleep 1

rm -f "$HLS_DIR"/cam*.ts "$HLS_DIR"/cam*.m3u8 2>/dev/null || true
mkdir -p "$HLS_DIR"

echo "=== start cam0 remux (20s) ==="
"$FFMPEG" -y -loglevel info -rtsp_transport tcp \
	-analyzeduration 2000000 -probesize 1000000 \
	-i "rtsp://127.0.0.1:${PORT}/cam0" -an -c:v copy -bsf:v h264_mp4toannexb \
	-f hls -hls_time 2 -hls_list_size 5 \
	-hls_flags delete_segments+append_list+omit_endlist+independent_segments \
	-hls_segment_filename "$HLS_DIR/cam0_%03d.ts" \
	"$HLS_DIR/cam0.m3u8" > /tmp/debug_hls_cam0.log 2>&1 &
PID=$!
echo "pid=$PID"

i=0
while [ "$i" -lt 20 ]; do
	if [ -s "$HLS_DIR/cam0.m3u8" ]; then
		echo "OK: playlist ready"
		ls -la "$HLS_DIR"
		head -20 "$HLS_DIR/cam0.m3u8"
		echo "=== leave ffmpeg running pid=$PID ==="
		echo "refresh http://192.168.42.1:8080/"
		exit 0
	fi
	if ! kill -0 "$PID" 2>/dev/null; then
		echo "FAIL: ffmpeg exited"
		tail -40 /tmp/debug_hls_cam0.log
		exit 1
	fi
	sleep 1
	i=$((i + 1))
done

echo "FAIL: no playlist after 20s"
tail -60 /tmp/debug_hls_cam0.log
kill "$PID" 2>/dev/null || true
ls -la "$HLS_DIR"
exit 1
