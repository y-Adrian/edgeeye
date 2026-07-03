#!/bin/sh
# start_my_cam_rtsp.sh — 在板子上启动 EdgeEye RTSP 预览（edgeeye_cam）
#
# 用法：
#   ./start_my_cam_rtsp.sh                    # 读 edgeeye_cam.conf
#   ./start_my_cam_rtsp.sh gc2083
#   ./start_my_cam_rtsp.sh dual --res 720p
#   ./start_my_cam_rtsp.sh dual --reboot
#
# 默认后台运行；日志写到 /tmp/edgeeye_cam_rtsp.log
set -e

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh"
edgeeye_load_config

MODE="$EDGEEYE_MODE"
PORT="$EDGEEYE_PORT"
RES="$EDGEEYE_RES"
CLI_MODE=0
CLI_PORT=0
CLI_RES=0
FG=0
DO_REBOOT=0
PIDFILE=/tmp/edgeeye_cam_rtsp.pid
LOG=/tmp/edgeeye_cam_rtsp.log
BIN="${EDGEEYE_CAM:-/root/edgeeye_cam}"

usage() {
	echo "usage: $0 [gc2083|ov5647|dual] [--reboot] [--fg] [--port N] [--res 1080p|720p|480p]"
	echo "  无 positional 参数时使用 $EDGEEYE_CONF"
	echo "  dual 建议加 --reboot（单摄切双摄后 ION 常不足）"
}

hint_ion_failure() {
	echo ""
	echo "=== 双摄启动失败：内核 ION/ISP 内存不足 ==="
	echo "常见原因：刚跑过单摄或 vendor rtsp_server，媒体栈未完全释放。"
	echo "请 reboot 后再试："
	echo "  reboot"
	echo "Mac 侧一键："
	echo "  ./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both --start-board"
}

edgeeye_args() {
	case "$MODE" in
	dual) printf '%s' "--dual" ;;
	ov5647) printf '%s' "--single ov5647" ;;
	*) printf '%s' "--single gc2083" ;;
	esac
	if [ -n "$RES" ]; then
		printf ' --res %s' "$RES"
	fi
}

while [ $# -gt 0 ]; do
	case "$1" in
	gc2083|ov5647|dual)
		MODE="$1"
		CLI_MODE=1
		shift
		;;
	--reboot)
		DO_REBOOT=1
		shift
		;;
	--fg|--foreground)
		FG=1
		shift
		;;
	--port)
		PORT="$2"
		CLI_PORT=1
		shift 2
		;;
	--res|-r)
		RES="$2"
		CLI_RES=1
		shift 2
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		echo "unknown option: $1"
		usage
		exit 1
		;;
	esac
done

[ "$CLI_MODE" -eq 0 ] && MODE="$EDGEEYE_MODE"
[ "$CLI_PORT" -eq 0 ] && PORT="${RTSP_PORT:-$EDGEEYE_PORT}"
[ "$CLI_RES" -eq 0 ] && RES="$EDGEEYE_RES"

. "$DIR/my_cam_test_common.sh"

if [ ! -x "$BIN" ]; then
	echo "missing $BIN"
	echo "run: cd edgeeye-duos && make app && ./deploy"
	exit 1
fi

if [ "$MODE" = dual ] && [ "$DO_REBOOT" = 1 ]; then
	echo "rebooting before dual RTSP..."
	reboot
fi

my_cam_install_sensor_configs
my_cam_stop_media_deep
sh "$DIR/stop_my_cam_rtsp.sh" >/dev/null 2>&1 || true
my_cam_tmp_cleanup

case "$MODE" in
dual)
	URLS="rtsp://192.168.42.1:${PORT}/cam0 rtsp://192.168.42.1:${PORT}/cam1"
	echo "tip: 若单摄后切双摄失败，请 reboot 或加 --reboot"
	;;
gc2083|ov5647)
	URLS="rtsp://192.168.42.1:${PORT}/cam0"
	;;
esac

ARGS=$(edgeeye_args)
echo "=== start edgeeye_cam mode=$MODE port=$PORT res=${RES:-1080p} ==="
echo "log: $LOG"

if [ "$FG" = 1 ]; then
	# shellcheck disable=SC2086
	exec "$BIN" $ARGS -P "$PORT"
fi

: >"$LOG"
# shellcheck disable=SC2086
nohup "$BIN" $ARGS -P "$PORT" >>"$LOG" 2>&1 &
echo $! > "$PIDFILE"

ready=0
for i in $(seq 1 60); do
	if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
		echo "edgeeye_cam died during startup (${i}s)"
		tail -40 "$LOG" 2>/dev/null || true
		if grep -qE 'SYS_ION_ALLOC|StartViChn failed' "$LOG" 2>/dev/null; then
			hint_ion_failure
		fi
		exit 1
	fi
	if grep -qE 'EdgeEye RTSP ready|RTSP session chn' "$LOG" 2>/dev/null; then
		ready=1
		break
	fi
	if netstat -ln 2>/dev/null | grep -q ":$PORT " || \
	   ss -ln 2>/dev/null | grep -q ":$PORT"; then
		ready=1
		break
	fi
	sleep 1
done

if [ "$ready" -eq 0 ]; then
	echo "WARN: RTSP port $PORT not confirmed after 60s (process still running)"
	tail -30 "$LOG" 2>/dev/null || true
elif ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	echo "edgeeye_cam failed to stay alive"
	cat "$LOG" 2>/dev/null || true
	exit 1
fi

echo "edgeeye_cam started pid $(cat "$PIDFILE")"
echo "preview URLs:"
for url in $URLS; do
	echo "  $url"
done
echo "Mac:"
echo "  ./scripts/preview_my_cam_rtsp_mac.sh --mode $MODE --start-board"
