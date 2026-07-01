#!/bin/sh
# install_autostart.sh — 将 run_security.sh 安装为开机启动（Milk-V Duo S）
set -e

INIT=/etc/init.d/S99debris_security
SRC=/root/run_security.sh

if [ ! -x "$SRC" ]; then
    echo "missing $SRC — deploy scripts first"
    exit 1
fi

cat > "$INIT" <<'EOF'
#!/bin/sh
case "$1" in
    start)
        /root/run_security.sh >> /tmp/debris_autostart.log 2>&1 &
        ;;
    stop)
        if [ -x /root/stop_security.sh ]; then
            /root/stop_security.sh
        else
            for f in /tmp/motion_detect.pid /tmp/motion_detect_v4l2.pid \
                     /tmp/motion_recorder.pid /tmp/rtsp_server.pid; do
                [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null || true
            done
            rmmod debris 2>/dev/null || true
        fi
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
EOF

chmod +x "$INIT"
echo "installed $INIT"
echo "reboot or run: $INIT start"
