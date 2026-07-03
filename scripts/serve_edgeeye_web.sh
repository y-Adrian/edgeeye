#!/bin/sh
# serve_edgeeye_web.sh — busybox httpd 提供 Web 状态页 + JPEG 快照
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

# 写入运行时信息供 index.html 读取
IP=$(edgeeye_board_ip)
cat >"$WEB_ROOT/status.json" <<EOF
{"mode":"$EDGEEYE_MODE","port":$EDGEEYE_PORT,"res":"$EDGEEYE_RES","ip":"$IP","dual":$([ "$EDGEEYE_MODE" = dual ] && echo true || echo false)}
EOF

if edgeeye_resolve_ffmpeg >/dev/null 2>&1; then
	sh "$DIR/edgeeye_snapshots.sh" 2>/dev/null || true
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	echo "edgeeye web already on :$PORT"
	exit 0
fi

HTTPD=""
for c in busybox httpd /usr/sbin/httpd; do
	if command -v busybox >/dev/null 2>&1; then
		HTTPD="busybox httpd"
		break
	fi
done

if [ -z "$HTTPD" ]; then
	echo "no httpd (busybox) on board"
	exit 1
fi

# shellcheck disable=SC2086
nohup $HTTPD -f -p "$PORT" -h "$WEB_ROOT" >>/tmp/edgeeye_web.log 2>&1 &
echo $! >"$PIDFILE"
echo "edgeeye web http://$IP:$PORT/ (pid $(cat "$PIDFILE"))"
