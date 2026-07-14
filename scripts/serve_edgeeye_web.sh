#!/bin/sh
# serve_edgeeye_web.sh — Web 页：HLS 直播（默认）或 JPEG 快照
set -e

BOARD_DIR=/root
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh"
edgeeye_load_config

WEB_ROOT="$BOARD_DIR/web"
PIDFILE=/tmp/edgeeye_web.pid
PORT="${EDGEEYE_WEB_PORT:-8080}"
LIVE="${EDGEEYE_WEB_LIVE:-hls}"

if [ ! -d "$WEB_ROOT" ]; then
	echo "missing $WEB_ROOT — deploy web/"
	exit 1
fi

mkdir -p "$WEB_ROOT/snapshots" "$WEB_ROOT/hls"

IP=$(edgeeye_board_ip)
cat >"$WEB_ROOT/status.json" <<EOF
{"mode":"$EDGEEYE_MODE","port":$EDGEEYE_PORT,"res":"$EDGEEYE_RES","ip":"$IP","dual":$([ "$EDGEEYE_MODE" = dual ] && echo true || echo false),"web_live":"$LIVE"}
EOF

edgeeye_stop_web

case "$LIVE" in
hls)
	if [ -x "$DIR/edgeeye_hls.sh" ]; then
		sh "$DIR/edgeeye_hls.sh" || \
			echo "WARN: HLS remux failed — check ffmpeg HLS muxer / RTSP" >&2
	else
		echo "WARN: missing edgeeye_hls.sh" >&2
	fi
	;;
snapshot)
	if edgeeye_resolve_ffmpeg >/dev/null 2>&1; then
		sh "$DIR/edgeeye_snapshots.sh" 2>/dev/null || true
	else
		echo "snapshots disabled: no ffmpeg on board"
	fi
	;;
*)
	echo "unknown web_live=$LIVE (use hls|snapshot)" >&2
	exit 1
	;;
esac

if ! command -v python3 >/dev/null 2>&1; then
	echo "python3 required"
	exit 1
fi

: > /tmp/edgeeye_web.log
# 优先自定义服务器（正确 MIME）；退回 http.server
if [ -f "$DIR/edgeeye_http_server.py" ]; then
	nohup python3 "$DIR/edgeeye_http_server.py" "$PORT" "$WEB_ROOT" \
		>>/tmp/edgeeye_web.log 2>&1 &
else
	cd "$WEB_ROOT"
	nohup python3 -m http.server "$PORT" --bind 0.0.0.0 >>/tmp/edgeeye_web.log 2>&1 &
fi
echo $! >"$PIDFILE"
sleep 2

if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	echo "web server exited — see /tmp/edgeeye_web.log"
	tail -5 /tmp/edgeeye_web.log 2>/dev/null
	exit 1
fi

if ! netstat -ln 2>/dev/null | grep -q ":$PORT " && \
   ! ss -ln 2>/dev/null | grep -q ":$PORT"; then
	echo "port $PORT not listening"
	exit 1
fi

echo "edgeeye web http://$IP:$PORT/ live=$LIVE (pid $(cat "$PIDFILE"))"
