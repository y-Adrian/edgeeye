#!/bin/sh
# start_my_cam_rtsp.sh — 在板子上启动 my_cam_test RTSP 预览
#
# 用法：
#   ./start_my_cam_rtsp.sh gc2083
#   ./start_my_cam_rtsp.sh ov5647
#   ./start_my_cam_rtsp.sh dual
#   ./start_my_cam_rtsp.sh dual --reboot    # 双摄前重启（推荐）
#   ./start_my_cam_rtsp.sh dual --fg
#
# 默认后台运行；日志写到 /tmp/my_cam_test_rtsp.log
set -e

MODE="gc2083"
PORT="${RTSP_PORT:-8554}"
STREAM_SEC="${STREAM_SEC:-1800}"
FG=0
DO_REBOOT=0
PIDFILE=/tmp/my_cam_test_rtsp.pid
LOG=/tmp/my_cam_test_rtsp.log
BIN="${MY_CAM_TEST:-/root/my_cam_test}"
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

usage() {
	echo "usage: $0 [gc2083|ov5647|dual] [--reboot] [--fg] [--port N] [--seconds N]"
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

while [ $# -gt 0 ]; do
	case "$1" in
	gc2083|ov5647|dual)
		MODE="$1"
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
		shift 2
		;;
	--seconds|-s)
		STREAM_SEC="$2"
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
	my_cam_link_dual_sensor
	URLS="rtsp://192.168.42.1:${PORT}/cam0 rtsp://192.168.42.1:${PORT}/cam1"
	echo "tip: 若单摄后切双摄失败，请 reboot 或加 --reboot"
	;;
gc2083|ov5647)
	my_cam_resolve_sensor "$MODE"
	my_cam_link_sensor
	URLS="rtsp://192.168.42.1:${PORT}/cam0"
	;;
esac

echo "=== start_my_cam_rtsp mode=$MODE port=$PORT stream_sec=$STREAM_SEC ==="
echo "log: $LOG"

if [ "$FG" = 1 ]; then
	exec "$BIN" -p 5 -s "$STREAM_SEC" -P "$PORT"
fi

: >"$LOG"
nohup "$BIN" -p 5 -s "$STREAM_SEC" -P "$PORT" >>"$LOG" 2>&1 &
echo $! > "$PIDFILE"

ready=0
for i in $(seq 1 60); do
	if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
		echo "my_cam_test died during startup (${i}s)"
		tail -40 "$LOG" 2>/dev/null || true
		if grep -qE 'SYS_ION_ALLOC|StartViChn failed' "$LOG" 2>/dev/null; then
			hint_ion_failure
		fi
		exit 1
	fi
	if grep -q 'RTSP session chn' "$LOG" 2>/dev/null; then
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
	echo "my_cam_test failed to stay alive"
	cat "$LOG" 2>/dev/null || true
	exit 1
fi

echo "my_cam_test started pid $(cat "$PIDFILE")"
echo "preview URLs:"
for url in $URLS; do
	echo "  $url"
done
echo "Mac:"
echo "  ffplay -rtsp_transport tcp rtsp://192.168.42.1:${PORT}/cam0"
if [ "$MODE" = dual ]; then
	echo "  ffplay -rtsp_transport tcp rtsp://192.168.42.1:${PORT}/cam1"
fi
