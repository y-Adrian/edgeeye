#!/bin/sh
# stop_my_cam_rtsp.sh — 停止 my_cam_test RTSP 预览
set -e

PIDFILE=/tmp/my_cam_test_rtsp.pid

stop_by_pidfile() {
	if [ ! -f "$PIDFILE" ]; then
		return 0
	fi

	pid=$(cat "$PIDFILE" 2>/dev/null || true)
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		echo "stopping my_cam_test pid $pid"
		kill "$pid" 2>/dev/null || true
		sleep 2
	fi
	rm -f "$PIDFILE"
}

stop_by_scan() {
	ps | grep -v grep | grep -E '/my_cam_test([[:space:]]|$)' | awk '{print $1}' | \
	while read -r pid; do
		[ -n "$pid" ] || continue
		echo "stopping stray my_cam_test pid $pid"
		kill "$pid" 2>/dev/null || true
	done
}

stop_by_pidfile
stop_by_scan
echo "my_cam_test RTSP stopped"
