#!/bin/sh
# serve_edgeeye_web.sh — Web 状态页 + JPEG 快照（Duo S 无 busybox httpd，用 python3）
set -e

BOARD_DIR=/root
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh"
edgeeye_load_config

WEB_ROOT="$BOARD_DIR/web"
PIDFILE=/tmp/edgeeye_web.pid
PORT="${EDGEEYE_WEB_PORT:-8080}"

if [ ! -d "$WEB_ROOT" ]; then
	echo "missing $WEB_ROOT — deploy web/"
	exit 1
fi

mkdir -p "$WEB_ROOT/snapshots"

IP=$(edgeeye_board_ip)
cat >"$WEB_ROOT/status.json" <<EOF
{"mode":"$EDGEEYE_MODE","port":$EDGEEYE_PORT,"res":"$EDGEEYE_RES","ip":"$IP","dual":$([ "$EDGEEYE_MODE" = dual ] && echo true || echo false)}
EOF

if edgeeye_resolve_ffmpeg >/dev/null 2>&1; then
	# 重启快照服务以加载新 ffmpeg / 脚本
	if [ -f /tmp/edgeeye_snapshots.pid ]; then
		kill "$(cat /tmp/edgeeye_snapshots.pid)" 2>/dev/null || true
		rm -f /tmp/edgeeye_snapshots.pid
	fi
	sh "$DIR/edgeeye_snapshots.sh" 2>/dev/null || true
else
	echo "snapshots disabled: no ffmpeg on board"
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	if netstat -ln 2>/dev/null | grep -q ":$PORT " || \
	   ss -ln 2>/dev/null | grep -q ":$PORT"; then
		echo "edgeeye web already on :$PORT (pid $(cat "$PIDFILE"))"
		exit 0
	fi
fi

edgeeye_stop_web

if ! command -v python3 >/dev/null 2>&1; then
	echo "python3 required (busybox httpd not on Duo S)"
	exit 1
fi

: > /tmp/edgeeye_web.log
cd "$WEB_ROOT"
nohup python3 -m http.server "$PORT" --bind 0.0.0.0 >>/tmp/edgeeye_web.log 2>&1 &
echo $! >"$PIDFILE"
sleep 2

if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	echo "python http.server exited — see /tmp/edgeeye_web.log"
	tail -5 /tmp/edgeeye_web.log 2>/dev/null
	exit 1
fi

if ! netstat -ln 2>/dev/null | grep -q ":$PORT " && \
   ! ss -ln 2>/dev/null | grep -q ":$PORT"; then
	echo "port $PORT not listening"
	exit 1
fi

echo "edgeeye web http://$IP:$PORT/ (pid $(cat "$PIDFILE"))"
