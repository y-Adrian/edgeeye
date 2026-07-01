#!/bin/sh
# stop_motion_recorder.sh
PIDFILE=/tmp/motion_recorder.pid
if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
fi
pkill -f motion_recorder 2>/dev/null || true
echo "motion_recorder stopped"
