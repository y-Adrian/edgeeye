#!/bin/sh
# stop_motion_watch.sh
PIDFILE=/tmp/motion_watch.pid
if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
fi
pkill -f motion_watch.sh 2>/dev/null || true
echo "motion_watch stopped"
