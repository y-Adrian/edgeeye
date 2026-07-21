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
	EDGEEYE_COOLDOWN_SEC="${EDGEEYE_COOLDOWN_SEC:-60}"
	EDGEEYE_MOTION_SOURCE="${EDGEEYE_MOTION_SOURCE:-rtsp}"
	EDGEEYE_MOTION_THRESHOLD="${EDGEEYE_MOTION_THRESHOLD:-15000}"
	EDGEEYE_MOTION_INTERVAL_SEC="${EDGEEYE_MOTION_INTERVAL_SEC:-5}"
	EDGEEYE_MOTION_RTSP="${EDGEEYE_MOTION_RTSP:-cam0}"
	EDGEEYE_CLIP_DIR="${EDGEEYE_CLIP_DIR:-}"
	EDGEEYE_WEB="${EDGEEYE_WEB:-0}"
	EDGEEYE_WEB_PORT="${EDGEEYE_WEB_PORT:-8080}"
	EDGEEYE_WEB_LIVE="${EDGEEYE_WEB_LIVE:-hls}"
	EDGEEYE_SNAPSHOT_SEC="${EDGEEYE_SNAPSHOT_SEC:-3}"
	EDGEEYE_AUTOSTART="${EDGEEYE_AUTOSTART:-0}"
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
	motion_source)
		case "$val" in
		rtsp|debris|gpio|auto) EDGEEYE_MOTION_SOURCE="$val" ;;
		*) echo "edgeeye_cam.conf: unknown motion_source=$val" >&2 ;;
		esac
		;;
	motion_threshold) EDGEEYE_MOTION_THRESHOLD="$val" ;;
	motion_interval_sec) EDGEEYE_MOTION_INTERVAL_SEC="$val" ;;
	motion_rtsp)
		case "$val" in
		cam0|cam1) EDGEEYE_MOTION_RTSP="$val" ;;
		*) echo "edgeeye_cam.conf: unknown motion_rtsp=$val (use cam0|cam1)" >&2 ;;
		esac
		;;
	clip_dir) EDGEEYE_CLIP_DIR="$val" ;;
	web) EDGEEYE_WEB="$val" ;;
	web_port) EDGEEYE_WEB_PORT="$val" ;;
	web_live)
		case "$val" in
		hls|snapshot) EDGEEYE_WEB_LIVE="$val" ;;
		*) echo "edgeeye_cam.conf: unknown web_live=$val (use hls|snapshot)" >&2 ;;
		esac
		;;
	snapshot_sec) EDGEEYE_SNAPSHOT_SEC="$val" ;;
	autostart) EDGEEYE_AUTOSTART="$val" ;;
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
	# 固定路径优先；勿先 source media_tools（cwd=/root 时会把 ./ffmpeg 误报成 bare "ffmpeg"）
	for p in /mnt/data/bin/ffmpeg /mnt/system/usr/bin/ffmpeg /usr/bin/ffmpeg; do
		if [ -x "$p" ]; then
			printf '%s' "$p"
			return 0
		fi
	done
	if command -v ffmpeg >/dev/null 2>&1; then
		command -v ffmpeg
		return 0
	fi
	if [ -f "$BOARD_DIR/media_tools.sh" ]; then
		# shellcheck disable=SC1091
		. "$BOARD_DIR/media_tools.sh"
		case "$FFMPEG" in
		/*)
			if [ -x "$FFMPEG" ]; then
				printf '%s' "$FFMPEG"
				return 0
			fi
			;;
		esac
	fi
	return 1
}

edgeeye_resolve_ffprobe() {
	for p in /mnt/data/bin/ffprobe /usr/bin/ffprobe ffprobe; do
		if [ -x "$p" ]; then
			printf '%s' "$p"
			return 0
		fi
		if command -v "$p" >/dev/null 2>&1; then
			printf '%s' "$p"
			return 0
		fi
	done
	return 1
}

edgeeye_ffprobe_rtsp_stream() {
	url="$1"
	probe=""

	probe=$(edgeeye_resolve_ffprobe) || return 1
	"$probe" -rtsp_transport tcp -v quiet \
		-show_entries stream=codec_name \
		-of default=nw=1 "$url" 2>/dev/null | grep -q codec_name
}

edgeeye_wait_rtsp_ready() {
	max="${1:-90}"
	scope="${2:-all}"
	i=0
	cam0_url="rtsp://127.0.0.1:${EDGEEYE_PORT}/cam0"
	cam1_url="rtsp://127.0.0.1:${EDGEEYE_PORT}/cam1"

	while [ "$i" -lt "$max" ]; do
		if edgeeye_cam_alive && edgeeye_rtsp_port_listening "$EDGEEYE_PORT"; then
			if edgeeye_ffprobe_rtsp_stream "$cam0_url"; then
				if [ "$scope" = "cam0" ]; then
					return 0
				fi
				if [ "$EDGEEYE_MODE" = "dual" ]; then
					if edgeeye_ffprobe_rtsp_stream "$cam1_url"; then
						return 0
					fi
				else
					return 0
				fi
			fi
			if ! edgeeye_resolve_ffprobe >/dev/null; then
				return 0
			fi
		fi
		sleep 1
		i=$((i + 1))
	done
	return 1
}

edgeeye_motion_rtsp_url() {
	case "${EDGEEYE_MOTION_RTSP:-cam0}" in
	cam1) printf '%s' "rtsp://127.0.0.1:${EDGEEYE_PORT}/cam1" ;;
	*)    printf '%s' "rtsp://127.0.0.1:${EDGEEYE_PORT}/cam0" ;;
	esac
}

edgeeye_web_port_listening() {
	port="${1:-${EDGEEYE_WEB_PORT:-8080}}"
	netstat -ln 2>/dev/null | grep -q ":$port " ||
		ss -ln 2>/dev/null | grep -q ":$port"
}

edgeeye_wait_web_port() {
	port="${1:-${EDGEEYE_WEB_PORT:-8080}}"
	max="${2:-15}"
	i=0
	while [ "$i" -lt "$max" ]; do
		if edgeeye_web_port_listening "$port"; then
			return 0
		fi
		sleep 1
		i=$((i + 1))
	done
	return 1
}

edgeeye_ffmpeg_has_hls() {
	ffmpeg=""
	ffmpeg=$(edgeeye_resolve_ffmpeg) || return 1
	# muxers 行形如 "  E hls             Apple HTTP Live Streaming"
	"$ffmpeg" -hide_banner -muxers 2>/dev/null | grep -qE '[[:space:]]hls[[:space:]]'
}

edgeeye_clip_dir() {
	if [ -n "$EDGEEYE_CLIP_DIR" ]; then
		printf '%s' "$EDGEEYE_CLIP_DIR"
		return 0
	fi
	if [ -d /mnt/sd ] && [ -w /mnt/sd ]; then
		printf '%s' "/mnt/sd/clips"
	else
		printf '%s' "/mnt/data/clips"
	fi
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

	if ! edgeeye_wait_rtsp_ready 120 cam0; then
		echo "skip record: RTSP cam0 not ready after 120s (no motion_recorder)" >>"$log"
		return 0
	fi

	case "$EDGEEYE_MOTION_SOURCE" in
	debris|gpio)
		if ! lsmod | grep -q '^debris '; then
			if [ -f "$BOARD_DIR/debris.ko" ]; then
				insmod "$BOARD_DIR/debris.ko" register_fallback_pdev=0 i2c_sensor_mode=0 \
					gpio_btn=500 >>"$log" 2>&1 || true
			fi
		fi
		;;
	esac

	export RTSP_URL="$(edgeeye_motion_rtsp_url)"
	# 双摄推流 cam0+cam1；动检/录像默认只占用一路（cam0），勿设 RTSP_URL2
	unset RTSP_URL2
	export MOTION_SOURCE="$EDGEEYE_MOTION_SOURCE"
	export MOTION_THRESHOLD="$EDGEEYE_MOTION_THRESHOLD"
	export MOTION_INTERVAL_SEC="$EDGEEYE_MOTION_INTERVAL_SEC"
	CLIP_DIR=$(edgeeye_clip_dir)
	export CLIP_DIR
	export FFMPEG
	FFMPEG=$(edgeeye_resolve_ffmpeg) || true
	export FFMPEG

	mkdir -p "$CLIP_DIR" 2>/dev/null || true

	if [ -f /tmp/motion_recorder.pid ] && kill -0 "$(cat /tmp/motion_recorder.pid)" 2>/dev/null; then
		echo "motion_recorder already running" >>"$log"
		return 0
	fi

	nohup "$BOARD_DIR/motion_recorder" "$EDGEEYE_CLIP_SEC" "$EDGEEYE_COOLDOWN_SEC" \
		>>"$log" 2>&1 &
	echo $! > /tmp/motion_recorder.pid
	echo "motion_recorder pid $(cat /tmp/motion_recorder.pid) source=$EDGEEYE_MOTION_SOURCE motion_rtsp=${EDGEEYE_MOTION_RTSP:-cam0} url=$RTSP_URL (dual preview unchanged)" >>"$log"
}

edgeeye_stop_recording() {
	if [ -f /tmp/motion_recorder.pid ]; then
		kill "$(cat /tmp/motion_recorder.pid)" 2>/dev/null || true
		rm -f /tmp/motion_recorder.pid
	fi
}

edgeeye_stop_hls() {
	for tag in cam0 cam1; do
		pf="/tmp/edgeeye_hls_${tag}.pid"
		if [ -f "$pf" ]; then
			kill "$(cat "$pf")" 2>/dev/null || true
			rm -f "$pf"
		fi
	done
	# 按 PID 杀 remux；勿用 pkill -f web/hls（会误伤 cmdline 含该串的 ssh）
	ps w 2>/dev/null | awk '/ffmpeg/ && /-f hls/ && /8554/ {print $1}' | while read -r pid; do
		[ -n "$pid" ] || continue
		kill "$pid" 2>/dev/null || true
	done
	sleep 1
	ps w 2>/dev/null | awk '/ffmpeg/ && /-f hls/ && /8554/ {print $1}' | while read -r pid; do
		[ -n "$pid" ] || continue
		kill -9 "$pid" 2>/dev/null || true
	done
}

edgeeye_stop_web() {
	edgeeye_stop_hls
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
	pkill -f "edgeeye_http_server.py" 2>/dev/null || true
}

EDGEEYE_INIT_SCRIPT="/etc/init.d/S99edgeeye_cam"

edgeeye_autostart_install() {
	if [ ! -x "$BOARD_DIR/run_edgeeye_stack.sh" ]; then
		echo "missing $BOARD_DIR/run_edgeeye_stack.sh — deploy scripts first" >&2
		return 1
	fi

	cat >"$EDGEEYE_INIT_SCRIPT" <<'EOF'
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
	chmod +x "$EDGEEYE_INIT_SCRIPT"
	echo "autostart enabled: $EDGEEYE_INIT_SCRIPT"
	return 0
}

edgeeye_autostart_remove() {
	if [ -f "$EDGEEYE_INIT_SCRIPT" ]; then
		rm -f "$EDGEEYE_INIT_SCRIPT"
		echo "autostart disabled: removed $EDGEEYE_INIT_SCRIPT"
	else
		echo "autostart already off (no init script)"
	fi
}

# 按 edgeeye_cam.conf 的 autostart=0|1 安装或移除 init.d
edgeeye_apply_autostart() {
	edgeeye_load_config
	if [ "$EDGEEYE_AUTOSTART" = "1" ]; then
		edgeeye_autostart_install
	else
		edgeeye_autostart_remove
	fi
}

edgeeye_autostart_status() {
	edgeeye_load_config
	echo "config $EDGEEYE_CONF: autostart=$EDGEEYE_AUTOSTART web=$EDGEEYE_WEB record=$EDGEEYE_RECORD"
	if [ -f "$EDGEEYE_INIT_SCRIPT" ]; then
		echo "init.d: installed ($EDGEEYE_INIT_SCRIPT)"
	else
		echo "init.d: not installed"
	fi
}
