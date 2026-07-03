#!/bin/sh
# preview_my_cam_rtsp_mac.sh — 在 Mac 上预览板子 my_cam_test RTSP
#
# 用法：
#   ./scripts/preview_my_cam_rtsp_mac.sh --mode gc2083 --start-board
#   ./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam both --start-board
#   ./scripts/preview_my_cam_rtsp_mac.sh --mode dual --cam cam0 --record 10
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
MODE="gc2083"
CAM="cam0"
PORT="${RTSP_PORT:-8554}"
START_BOARD=0
REBOOT_BOARD=0
NO_REBOOT_BOARD=0
RECORD_SEC=0
READY_TIMEOUT="${READY_TIMEOUT:-60}"
FFPLAY_BIN="${FFPLAY_BIN:-ffplay}"
FFPROBE_BIN="${FFPROBE_BIN:-ffprobe}"
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new}"
LOG0=/tmp/cam0_ffplay.log
LOG1=/tmp/cam1_ffplay.log

usage() {
	cat <<'EOF'
Usage: preview_my_cam_rtsp_mac.sh [options]

  --mode gc2083|ov5647|dual   sensor profile (default gc2083)
  --cam cam0|cam1|both        preview path (dual only for cam1/both)
  --start-board               SSH 到板子执行 start_my_cam_rtsp.sh
  --reboot-board              启动前先 reboot（双摄推荐，默认 dual+start-board 时开启）
  --no-reboot-board           跳过 reboot（单摄切双摄后可能 ION 失败）
  --record N                  录 N 秒 mp4 到 /tmp（不弹窗）
  --port N                    RTSP port (default 8554)
  --ready-timeout N           等流就绪秒数 (default 60)

提示：若未加 --start-board，须先在板上运行：
  ssh root@192.168.42.1 '/root/start_my_cam_rtsp.sh dual'
EOF
}

die() {
	echo "ERROR: $*"
	exit 1
}

run_remote_start() {
	echo ">>> starting board: start_my_cam_rtsp.sh $MODE"
	ssh $SSH_OPTS "$BOARD_USER@$BOARD_IP" \
		"cd /root && chmod +x ./start_my_cam_rtsp.sh ./stop_my_cam_rtsp.sh 2>/dev/null || true && ./start_my_cam_rtsp.sh $MODE"
}

board_reboot_and_wait() {
	echo ">>> rebooting board $BOARD_USER@$BOARD_IP ..."
	ssh $SSH_OPTS "$BOARD_USER@$BOARD_IP" reboot 2>/dev/null || \
		ssh $SSH_OPTS "$BOARD_USER@$BOARD_IP" "reboot" || true
	sleep 8
	max="${BOARD_REBOOT_TIMEOUT:-120}"
	i=0
	while [ "$i" -lt "$max" ]; do
		if ssh $SSH_OPTS "$BOARD_USER@$BOARD_IP" true 2>/dev/null; then
			sleep 5
			echo "board is up"
			return 0
		fi
		sleep 3
		i=$((i + 3))
	done
	die "board not reachable after reboot"
}

board_rtsp_pid_alive() {
	ssh $SSH_OPTS "$BOARD_USER@$BOARD_IP" \
		'[ -f /tmp/my_cam_test_rtsp.pid ] && kill -0 "$(cat /tmp/my_cam_test_rtsp.pid)" 2>/dev/null' \
		2>/dev/null
}

show_board_log_tail() {
	echo "--- board /tmp/my_cam_test_rtsp.log (last 30 lines) ---"
	ssh $SSH_OPTS "$BOARD_USER@$BOARD_IP" 'tail -30 /tmp/my_cam_test_rtsp.log 2>/dev/null || echo "(no log)"' \
		2>/dev/null || true
}

rtsp_url_ready() {
	url="$1"
	if ! command -v "$FFPROBE_BIN" >/dev/null 2>&1; then
		return 0
	fi
	"$FFPROBE_BIN" -rtsp_transport tcp -v error \
		-select_streams v:0 -show_entries stream=codec_name \
		-of csv=p=0 "$url" >/dev/null 2>&1
}

wait_rtsp_ready() {
	label="$1"
	url="$2"
	sec="$READY_TIMEOUT"

	if ! command -v "$FFPROBE_BIN" >/dev/null 2>&1; then
		echo "WARN: no ffprobe, skip ready check for $label"
		sleep 8
		return 0
	fi

	echo "waiting for $label ($url), up to ${sec}s..."
	i=0
	while [ "$i" -lt "$sec" ]; do
		if rtsp_url_ready "$url"; then
			echo "OK: $label stream ready (${i}s)"
			return 0
		fi
		sleep 1
		i=$((i + 1))
	done

	echo "FAIL: $label not ready after ${sec}s"
	return 1
}

probe_url() {
	url="$1"
	if command -v "$FFPROBE_BIN" >/dev/null 2>&1; then
		echo "--- ffprobe $url ---"
		"$FFPROBE_BIN" -rtsp_transport tcp -v error \
			-show_entries stream=codec_name,width,height \
			-of default=nw=1 "$url" 2>&1 || true
	else
		echo "skip ffprobe: $FFPROBE_BIN not found"
	fi
}

show_ffplay_log() {
	log="$1"
	label="$2"
	if [ -f "$log" ]; then
		echo "--- $label ffplay log ---"
		tail -20 "$log"
	fi
}

preview_one() {
	label="$1"
	url="$2"

	echo "=== preview $label ==="
	echo "URL: $url"
	wait_rtsp_ready "$label" "$url" || {
		show_board_log_tail
		die "$label RTSP not reachable — 先 ./deploy，再 --start-board 或板上 start_my_cam_rtsp.sh"
	}
	probe_url "$url"

	if [ "$RECORD_SEC" -gt 0 ]; then
		if command -v ffmpeg >/dev/null 2>&1; then
			out="/tmp/${label}_$(date +%Y%m%d_%H%M%S).mp4"
			echo "recording ${RECORD_SEC}s -> $out"
			ffmpeg -y -rtsp_transport tcp -i "$url" -c copy -t "$RECORD_SEC" "$out"
			echo "saved: $out"
			return 0
		fi
		die "ffmpeg not found; brew install ffmpeg"
	fi

	command -v "$FFPLAY_BIN" >/dev/null 2>&1 || die "ffplay not found — brew install ffmpeg"

	echo "opening ffplay (close window to exit)..."
	"$FFPLAY_BIN" -rtsp_transport tcp -window_title "$label" -loglevel warning "$url"
}

preview_dual_both() {
	url0="$1"
	url1="$2"

	wait_rtsp_ready cam0 "$url0" || {
		show_board_log_tail
		die "cam0 not ready"
	}
	wait_rtsp_ready cam1 "$url1" || {
		show_board_log_tail
		die "cam1 not ready (双摄须 dev_num=2 且板端 dual 模式)"
	}

	command -v "$FFPLAY_BIN" >/dev/null 2>&1 || die "ffplay not found — brew install ffmpeg"

	rm -f "$LOG0" "$LOG1"
	"$FFPLAY_BIN" -rtsp_transport tcp -window_title cam0 -loglevel warning "$url0" >"$LOG0" 2>&1 &
	pid0=$!
	sleep 1
	"$FFPLAY_BIN" -rtsp_transport tcp -window_title cam1 -loglevel warning "$url1" >"$LOG1" 2>&1 &
	pid1=$!

	echo "started ffplay cam0 pid=$pid0, cam1 pid=$pid1"
	echo "close both windows to exit; Ctrl+C here also stops preview"

	# ffplay 连不上会在 1～2 秒内退出；先做一次存活检查
	sleep 2
	alive0=0
	alive1=0
	kill -0 "$pid0" 2>/dev/null && alive0=1
	kill -0 "$pid1" 2>/dev/null && alive1=1

	if [ "$alive0" -eq 0 ]; then
		show_ffplay_log "$LOG0" cam0
		[ "$alive1" -eq 1 ] && kill "$pid1" 2>/dev/null || true
		show_board_log_tail
		die "cam0 ffplay exited immediately (see log above)"
	fi
	if [ "$alive1" -eq 0 ]; then
		show_ffplay_log "$LOG1" cam1
		kill "$pid0" 2>/dev/null || true
		die "cam1 ffplay exited immediately — 确认板上是 dual 模式且 cam1 在推流"
	fi

	# 阻塞到两路都结束
	while kill -0 "$pid0" 2>/dev/null || kill -0 "$pid1" 2>/dev/null; do
		sleep 1
	done

	wait "$pid0" 2>/dev/null || true
	wait "$pid1" 2>/dev/null || true
	echo "preview ended"
}

while [ $# -gt 0 ]; do
	case "$1" in
	--mode)
		MODE="$2"
		shift 2
		;;
	--cam)
		CAM="$2"
		shift 2
		;;
	--start-board)
		START_BOARD=1
		shift
		;;
	--reboot-board)
		REBOOT_BOARD=1
		shift
		;;
	--no-reboot-board)
		NO_REBOOT_BOARD=1
		shift
		;;
	--record)
		RECORD_SEC="$2"
		shift 2
		;;
	--port)
		PORT="$2"
		shift 2
		;;
	--ready-timeout)
		READY_TIMEOUT="$2"
		shift 2
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		die "unknown option: $1 (try --help)"
		;;
	esac
done

if [ "$MODE" != dual ] && [ "$CAM" = "cam1" -o "$CAM" = "both" ]; then
	die "non-dual mode only supports cam0"
fi

if ! ssh $SSH_OPTS "$BOARD_USER@$BOARD_IP" true 2>/dev/null; then
	die "cannot SSH to $BOARD_USER@$BOARD_IP"
fi

if [ "$START_BOARD" = 1 ]; then
	if [ "$MODE" = dual ] && [ "$NO_REBOOT_BOARD" != 1 ]; then
		REBOOT_BOARD=1
	fi
	if [ "$REBOOT_BOARD" = 1 ]; then
		board_reboot_and_wait
	fi
	run_remote_start
elif ! board_rtsp_pid_alive; then
	echo "WARN: board my_cam_test RTSP not running"
	echo "      add --start-board 或先: ssh $BOARD_USER@$BOARD_IP '/root/start_my_cam_rtsp.sh $MODE'"
fi

URL0="rtsp://${BOARD_IP}:${PORT}/cam0"
URL1="rtsp://${BOARD_IP}:${PORT}/cam1"

case "$CAM" in
cam0)
	preview_one cam0 "$URL0"
	;;
cam1)
	preview_one cam1 "$URL1"
	;;
both)
	if [ "$RECORD_SEC" -gt 0 ]; then
		preview_one cam0 "$URL0"
		preview_one cam1 "$URL1"
	else
		preview_dual_both "$URL0" "$URL1"
	fi
	;;
*)
	die "invalid --cam: $CAM"
	;;
esac
