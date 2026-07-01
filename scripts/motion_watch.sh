#!/bin/sh
# motion_watch.sh — 监视日志中的 MOTION 行，写入事件归档
#
# 用法：./motion_watch.sh [log_file] [out_file]
# 默认：/tmp/debris_security.log → /tmp/motion_clips.log
LOG="${1:-/tmp/debris_security.log}"
OUT="${2:-/tmp/motion_clips.log}"
PIDFILE=/tmp/motion_watch.pid

touch "$OUT"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "motion_watch already running"
    exit 0
fi

(
    while true; do
        if [ -f "$LOG" ]; then
            tail -n 0 -F "$LOG" 2>/dev/null | while IFS= read -r line; do
                case "$line" in
                    *MOTION*|*motion*)
                        echo "$(date '+%Y-%m-%dT%H:%M:%S') $line" >> "$OUT"
                        ;;
                esac
            done
        else
            sleep 2
        fi
    done
) >> /tmp/motion_watch.log 2>&1 &

echo $! > "$PIDFILE"
echo "motion_watch pid $(cat "$PIDFILE") -> $OUT"
