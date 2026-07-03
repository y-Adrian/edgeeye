# edgeeye_cam_common.sh — 读取 /root/edgeeye_cam.conf（须用 . 引入）
#
# 导出：
#   EDGEEYE_MODE   dual | gc2083 | ov5647
#   EDGEEYE_PORT   RTSP 端口
#   EDGEEYE_RES    1080p | 720p | 480p
#   EDGEEYE_BOOT_DELAY  自启等待秒数

EDGEEYE_CONF="${EDGEEYE_CONF:-/root/edgeeye_cam.conf}"

edgeeye_cfg_default() {
	EDGEEYE_MODE="${EDGEEYE_MODE:-dual}"
	EDGEEYE_PORT="${EDGEEYE_PORT:-8554}"
	EDGEEYE_RES="${EDGEEYE_RES:-720p}"
	EDGEEYE_BOOT_DELAY="${EDGEEYE_BOOT_DELAY:-8}"
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
