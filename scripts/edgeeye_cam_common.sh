# edgeeye_cam_common.sh — 读取 /root/edgeeye_cam.conf（须用 . 引入）

EDGEEYE_CONF="${EDGEEYE_CONF:-/root/edgeeye_cam.conf}"
BOARD_DIR="${BOARD_DIR:-/root}"

edgeeye_cfg_default() {
	EDGEEYE_MODE="${EDGEEYE_MODE:-dual}"
	EDGEEYE_PORT="${EDGEEYE_PORT:-8554}"
	EDGEEYE_RES="${EDGEEYE_RES:-720p}"
	EDGEEYE_BOOT_DELAY="${EDGEEYE_BOOT_DELAY:-8}"
	EDGEEYE_RECORD="${EDGEEYE_RECORD:-0}"
	EDGEEYE_CLIP_SEC="${EDGEEYE_CLIP_SEC:-30}"
	EDGEEYE_COOLDOWN_SEC="${EDGEEYE_COOLDOWN_SEC:-15}"
	EDGEEYE_WEB="${EDGEEYE_WEB:-1}"
	EDGEEYE_WEB_PORT="${EDGEEYE_WEB_PORT:-8080}"
	EDGEEYE_SNAPSHOT_SEC="${EDGEEYE_SNAPSHOT_SEC:-3}"
}

edgeeye_cfg_set_key() {
	key="$1"
	val="$2"

	case "$key" in
	mode)
		case "$val" in
		dual|gc2083|ov5647) EDGEEYE_MODE="$val" ;;
		*) echo "edgeeye_cam.conf: unknown mode=$val" >&2 ;;
		esac
		;;
	port) EDGEEYE_PORT="$val" ;;
	res)
		case "$val" in
		1080p|720p|480p|high|medium|low) EDGEEYE_RES="$val" ;;
		*) echo "edgeeye_cam.conf: unknown res=$val" >&2 ;;
		esac
		;;
	boot_delay) EDGEEYE_BOOT_DELAY="$val" ;;
	record) EDGEEYE_RECORD="$val" ;;
	clip_sec) EDGEEYE_CLIP_SEC="$val" ;;
	cooldown_sec) EDGEEYE_COOLDOWN_SEC="$val" ;;
	web) EDGEEYE_WEB="$val" ;;
	web_port) EDGEEYE_WEB_PORT="$val" ;;
	snapshot_sec) EDGEEYE_SNAPSHOT_SEC="$val" ;;
	esac
}

edgeeye_load_config() {
	edgeeye_cfg_default
	[ -f "$EDGEEYE_CONF" ] || return 0

	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
		''|'#'*) continue ;;
		esac
		key=${line%%=*}
		val=${line#*=}
		key=$(printf '%s' "$key" | tr -d ' \t')
		val=$(printf '%s' "$val" | tr -d ' \t')
		[ -n "$key" ] || continue
		edgeeye_cfg_set_key "$key" "$val"
	done < "$EDGEEYE_CONF"
}

edgeeye_cam_alive() {
	[ -f /tmp/edgeeye_cam_rtsp.pid ] &&
		kill -0 "$(cat /tmp/edgeeye_cam_rtsp.pid)" 2>/dev/null
}

edgeeye_rtsp_port_listening() {
	port="${1:-$EDGEEYE_PORT}"
	netstat -ln 2>/dev/null | grep -q ":$port " ||
		ss -ln 2>/dev/null | grep -q ":$port"
}

edgeeye_board_ip() {
	ip=$(ip -4 addr show usb0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)
	if [ -n "$ip" ]; then
		printf '%s' "$ip"
		return 0
	fi
	printf '%s' "192.168.42.1"
}

edgeeye_resolve_ffmpeg() {
	if [ -f "$BOARD_DIR/media_tools.sh" ]; then
		# shellcheck disable=SC1091
		. "$BOARD_DIR/media_tools.sh"
	fi
	if [ -n "$FFMPEG" ] && [ -x "$FFMPEG" ]; then
		printf '%s' "$FFMPEG"
		return 0
	fi
	for p in /mnt/data/bin/ffmpeg /mnt/system/usr/bin/ffmpeg /usr/bin/ffmpeg ffmpeg; do
		if command -v "$p" >/dev/null 2>&1 || [ -x "$p" ]; then
			printf '%s' "$p"
			return 0
		fi
	done
	return 1
}

edgeeye_wait_rtsp_ready() {
	max="${1:-90}"
	i=0
	while [ "$i" -lt "$max" ]; do
		if edgeeye_cam_alive && edgeeye_rtsp_port_listening "$EDGEEYE_PORT"; then
			if command -v ffprobe >/dev/null 2>&1; then
				if ffprobe -rtsp_transport tcp -v quiet \
					-show_entries stream=codec_name \
					-of default=nw=1 \
					"rtsp://127.0.0.1:${EDGEEYE_PORT}/cam0" 2>/dev/null | \
					grep -q codec_name; then
					return 0
				fi
			else
				return 0
			fi
		fi
		sleep 1
		i=$((i + 1))
	done
	return 1
}

edgeeye_start_recording() {
	log="${1:-/tmp/edgeeye_stack.log}"

	[ "$EDGEEYE_RECORD" = "1" ] || return 0
	[ -x "$BOARD_DIR/motion_recorder" ] || {
		echo "skip record: no motion_recorder" >>"$log"
		return 0
	}
	if ! edgeeye_resolve_ffmpeg >/dev/null; then
		echo "skip record: no ffmpeg on board" >>"$log"
		return 0
	fi

	if ! lsmod | grep -q '^debris '; then
		if [ -f "$BOARD_DIR/debris.ko" ]; then
			insmod "$BOARD_DIR/debris.ko" register_fallback_pdev=0 i2c_sensor_mode=0 \
				>>"$log" 2>&1 || true
		fi
	fi

	export RTSP_URL="rtsp://127.0.0.1:${EDGEEYE_PORT}/cam0"
	if [ "$EDGEEYE_MODE" = "dual" ]; then
		export RTSP_URL2="rtsp://127.0.0.1:${EDGEEYE_PORT}/cam1"
	else
		unset RTSP_URL2
	fi
	export FFMPEG
	FFMPEG=$(edgeeye_resolve_ffmpeg) || true
	export FFMPEG

	if [ -f /tmp/motion_recorder.pid ] && kill -0 "$(cat /tmp/motion_recorder.pid)" 2>/dev/null; then
		echo "motion_recorder already running" >>"$log"
		return 0
	fi

	nohup "$BOARD_DIR/motion_recorder" "$EDGEEYE_CLIP_SEC" "$EDGEEYE_COOLDOWN_SEC" \
		>>"$log" 2>&1 &
	echo $! > /tmp/motion_recorder.pid
	echo "motion_recorder pid $(cat /tmp/motion_recorder.pid)" >>"$log"
}

edgeeye_stop_recording() {
	if [ -f /tmp/motion_recorder.pid ]; then
		kill "$(cat /tmp/motion_recorder.pid)" 2>/dev/null || true
		rm -f /tmp/motion_recorder.pid
	fi
}

edgeeye_stop_web() {
	if [ -f /tmp/edgeeye_snapshots.pid ]; then
		kill "$(cat /tmp/edgeeye_snapshots.pid)" 2>/dev/null || true
		rm -f /tmp/edgeeye_snapshots.pid
	fi
	if [ -f /tmp/edgeeye_web.pid ]; then
		kill "$(cat /tmp/edgeeye_web.pid)" 2>/dev/null || true
		rm -f /tmp/edgeeye_web.pid
	fi
	pkill -f "python3 -m http.server ${EDGEEYE_WEB_PORT:-8080}" 2>/dev/null || true
	pkill -f "busybox httpd.*${EDGEEYE_WEB_PORT:-8080}" 2>/dev/null || true
}
