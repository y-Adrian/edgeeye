#!/bin/sh
# install_autostart.sh — 安装 edgeeye_cam 开机自启（Milk-V Duo S）
#
# 用法：
#   ./install_autostart.sh          # edgeeye_cam（默认）
#   ./install_autostart.sh security # 旧安防栈 run_security.sh
set -e

STACK="${1:-edgeeye}"
INIT_EDGE=/etc/init.d/S99edgeeye_cam
INIT_SEC=/etc/init.d/S99debris_security

install_edgeeye() {
	if [ ! -x /root/run_edgeeye_cam.sh ]; then
		echo "missing /root/run_edgeeye_cam.sh — deploy scripts first"
		exit 1
	fi

	cat > "$INIT_EDGE" <<'EOF'
#!/bin/sh
case "$1" in
    start)
        /root/run_edgeeye_cam.sh &
        ;;
    stop)
        if [ -x /root/stop_my_cam_rtsp.sh ]; then
            /root/stop_my_cam_rtsp.sh
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
EOF
	chmod +x "$INIT_EDGE"
	[ -f "$INIT_SEC" ] && rm -f "$INIT_SEC"
	echo "installed $INIT_EDGE (edgeeye_cam)"
	echo "config: /root/edgeeye_cam.conf"
	echo "log:    /tmp/edgeeye_autostart.log"
	echo "test:   reboot  或  $INIT_EDGE start"
}

install_security() {
	SRC=/root/run_security.sh
	if [ ! -x "$SRC" ]; then
		echo "missing $SRC — deploy scripts first"
		exit 1
	fi

	cat > "$INIT_SEC" <<'EOF'
#!/bin/sh
case "$1" in
    start)
        /root/run_security.sh >> /tmp/debris_autostart.log 2>&1 &
        ;;
    stop)
        if [ -x /root/stop_security.sh ]; then
            /root/stop_security.sh
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
	chmod +x "$INIT_SEC"
	[ -f "$INIT_EDGE" ] && rm -f "$INIT_EDGE"
	echo "installed $INIT_SEC (legacy run_security)"
}

case "$STACK" in
edgeeye|cam|"") install_edgeeye ;;
security|debris) install_security ;;
*)
	echo "usage: $0 [edgeeye|security]"
	exit 1
	;;
esac
