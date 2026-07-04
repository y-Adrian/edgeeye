#!/bin/sh
# install_autostart.sh — 安装 edgeeye 产品栈开机自启（Milk-V Duo S）
#
# 用法：./install_autostart.sh
set -e

INIT_EDGE=/etc/init.d/S99edgeeye_cam

if [ ! -x /root/run_edgeeye_stack.sh ]; then
	echo "missing /root/run_edgeeye_stack.sh — deploy scripts first"
	exit 1
fi

cat > "$INIT_EDGE" <<'EOF'
#!/bin/sh
case "$1" in
    start)
        /root/run_edgeeye_stack.sh &
        ;;
    stop)
        if [ -x /root/stop_edgeeye_stack.sh ]; then
            /root/stop_edgeeye_stack.sh
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
echo "installed $INIT_EDGE"
echo "config: /root/edgeeye_cam.conf"
echo "log:    /tmp/edgeeye_stack.log"
echo "test:   reboot  或  $INIT_EDGE start"
