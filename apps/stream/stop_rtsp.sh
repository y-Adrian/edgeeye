#!/bin/sh
# stop_rtsp.sh — 停止 rtsp_server（无 pkill 的 BusyBox 可用）
PIDFILE=/tmp/rtsp_server.pid

if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
fi
# Milk-V rootfs 常无 pkill；用 ps+kill 兜底
for _pid in $(ps | grep rtsp_server | grep -v grep | awk '{print $1}'); do
    kill "$_pid" 2>/dev/null || true
done
echo "rtsp_server stopped"
