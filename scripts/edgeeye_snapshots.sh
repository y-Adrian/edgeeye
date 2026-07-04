#!/bin/sh
# edgeeye_snapshots.sh — 从 RTSP 周期性抓取 JPEG 供 Web 预览
#
# 后台运行；PID /tmp/edgeeye_snapshots.pid
set -e

BOARD_DIR=/root
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh"
edgeeye_load_config

SNAP_DIR="$BOARD_DIR/web/snapshots"
PIDFILE=/tmp/edgeeye_snapshots.pid
LOG=/tmp/edgeeye_snapshots.log

mkdir -p "$SNAP_DIR"

FFMPEG=$(edgeeye_resolve_ffmpeg) || {
	echo "edgeeye_snapshots: no ffmpeg" >>"$LOG"
	exit 1
}

# 清理占用 RTSP 的残留 ffmpeg（旧版脚本易挂死）
for p in $(ps | grep ffmpeg | grep "127.0.0.1:${EDGEEYE_PORT}" | awk '{print $1}'); do
	kill "$p" 2>/dev/null || true
done

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	echo "edgeeye_snapshots already running"
	exit 0
fi

snap_timeout() {
	if command -v timeout >/dev/null 2>&1; then
		timeout "$1" "$2" "${@:3}"
	else
		"$2" "${@:3}"
	fi
}

grab_one() {
	tag="$1"
	url="rtsp://127.0.0.1:${EDGEEYE_PORT}/${tag}"
	out="$SNAP_DIR/${tag}.jpg"
	tmp="$SNAP_DIR/.${tag}.jpg.tmp"
	# 软解 H.264 较慢；缩略图 + 超时，避免阻塞 RTSP
	if ! snap_timeout 120 "$FFMPEG" -y -loglevel warning -rtsp_transport tcp \
		-analyzeduration 1000000 -probesize 500000 \
		-i "$url" -vf scale=640:-1 -frames:v 1 -q:v 8 "$tmp" 2>>"$LOG"; then
		rm -f "$tmp"
		return 1
	fi
	[ -s "$tmp" ] || { rm -f "$tmp"; return 1; }
	mv "$tmp" "$out"
}

(
	while true; do
		if edgeeye_cam_alive || edgeeye_rtsp_port_listening "$EDGEEYE_PORT"; then
			grab_one cam0
			if [ "$EDGEEYE_MODE" = "dual" ]; then
				grab_one cam1
			fi
		fi
		sleep "${EDGEEYE_SNAPSHOT_SEC:-3}"
	done
) >>"$LOG" 2>&1 &

echo $! >"$PIDFILE"
echo "edgeeye_snapshots pid $(cat "$PIDFILE") -> $SNAP_DIR"
