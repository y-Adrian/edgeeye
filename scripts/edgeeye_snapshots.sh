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

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	echo "edgeeye_snapshots already running"
	exit 0
fi

grab_one() {
	tag="$1"
	url="rtsp://127.0.0.1:${EDGEEYE_PORT}/${tag}"
	out="$SNAP_DIR/${tag}.jpg"
	"$FFMPEG" -y -loglevel error -rtsp_transport tcp \
		-i "$url" -frames:v 1 -q:v 5 "$out" 2>/dev/null || true
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
