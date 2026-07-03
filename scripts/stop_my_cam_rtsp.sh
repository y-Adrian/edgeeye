#!/bin/sh
# stop_my_cam_rtsp.sh — 停止 edgeeye_cam RTSP 预览
set -e

PIDFILE=/tmp/edgeeye_cam_rtsp.pid
LEGACY_PIDFILE=/tmp/my_cam_test_rtsp.pid

stop_by_pidfile() {
	for f in "$PIDFILE" "$LEGACY_PIDFILE"; do
		[ -f "$f" ] || continue
		pid=$(cat "$f" 2>/dev/null || true)
		if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
			echo "stopping RTSP pid $pid"
			kill "$pid" 2>/dev/null || true
			sleep 2
		fi
		rm -f "$f"
	done
}

stop_by_scan() {
	ps | grep -v grep | grep -E '/edgeeye_cam([[:space:]]|$)|/my_cam_test([[:space:]]|$)' | \
		awk '{print $1}' | while read -r pid; do
		[ -n "$pid" ] || continue
		echo "stopping stray camera pid $pid"
		kill "$pid" 2>/dev/null || true
	done
}

stop_by_pidfile
stop_by_scan
echo "RTSP preview stopped"
