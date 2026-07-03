# lib_board.sh — Mac 侧 SSH/板上自动化小工具（须 source）

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
BOARD_DIR="${BOARD_DIR:-/root}"
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new}"

board_ssh() {
	ssh $SSH_OPTS "$BOARD_USER@$BOARD_IP" "$@"
}

board_scp() {
	scp $SSH_OPTS "$@"
}

board_ping() {
	board_ssh true 2>/dev/null
}

board_wait_up() {
	max="${1:-90}"
	interval="${2:-3}"
	echo "waiting for $BOARD_USER@$BOARD_IP (max ${max}s)..."
	i=0
	while [ "$i" -lt "$max" ]; do
		if board_ping; then
			sleep 5
			echo "board is up"
			return 0
		fi
		i=$((i + interval))
		sleep "$interval"
	done
	echo "board not reachable after ${max}s"
	return 1
}

board_reboot_and_wait() {
	echo "rebooting $BOARD_USER@$BOARD_IP..."
	board_ssh reboot 2>/dev/null || board_ssh "reboot" || true
	sleep 5
	board_wait_up "${BOARD_REBOOT_TIMEOUT:-120}"
}

board_install_sensor_configs() {
	board_ssh "mkdir -p /mnt/data && for f in sensor_cfg_GC2083.ini sensor_cfg_OV5647_J2.ini sensor_cfg_GC2083_OV5647_dual.ini; do \
		[ -f /mnt/data/\$f ] || { [ -f $BOARD_DIR/stream/\$f ] && cp $BOARD_DIR/stream/\$f /mnt/data/\$f && echo installed \$f; }; \
	done"
}

board_fetch_logs_on_fail() {
	dest="${1:-/tmp/edgeeye_cam_logs}"
	mkdir -p "$dest"
	echo "fetching board logs -> $dest"
	board_scp "$BOARD_USER@$BOARD_IP:/tmp/my_cam_test"*.log "$dest/" 2>/dev/null || true
	board_scp "$BOARD_USER@$BOARD_IP:/tmp/cam*.yuv" "$dest/" 2>/dev/null || true
	board_scp "$BOARD_USER@$BOARD_IP:/tmp/cam*.h264" "$dest/" 2>/dev/null || true
}
