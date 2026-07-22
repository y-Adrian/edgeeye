#!/bin/sh
# install_ffmpeg_cli_board.sh — 部署静态 ffmpeg 到板子 /mnt/data/bin/ffmpeg
#
# 优先使用 output/ffmpeg-riscv64-static（build_ffmpeg_cli.sh 写入，与 ./deploy 同源）
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
FFMPEG="${FFMPEG_BIN:-}"

if [ -z "$FFMPEG" ]; then
	if [ -x "$ROOT/output/ffmpeg-riscv64-static" ]; then
		FFMPEG="$ROOT/output/ffmpeg-riscv64-static"
	elif [ -x /tmp/debris_ffmpeg_out/bin/ffmpeg ]; then
		FFMPEG=/tmp/debris_ffmpeg_out/bin/ffmpeg
	fi
fi

if [ ! -x "$FFMPEG" ]; then
	echo "missing ffmpeg — run build_ffmpeg_cli.sh in Docker first" >&2
	echo "  expect: $ROOT/output/ffmpeg-riscv64-static" >&2
	exit 1
fi

echo "install $FFMPEG -> board:/mnt/data/bin/ffmpeg"
file "$FFMPEG"
ssh "$BOARD_USER@$BOARD_IP" "mkdir -p /mnt/data/bin"
scp "$FFMPEG" "$BOARD_USER@$BOARD_IP:/mnt/data/bin/ffmpeg"
ssh "$BOARD_USER@$BOARD_IP" "chmod +x /mnt/data/bin/ffmpeg"

ssh "$BOARD_USER@$BOARD_IP" \
	'/mnt/data/bin/ffmpeg -hide_banner -muxers 2>/dev/null | grep hls || { echo "board: ffmpeg still missing HLS"; exit 1; }'
ssh "$BOARD_USER@$BOARD_IP" \
	'/mnt/data/bin/ffmpeg -hide_banner -demuxers 2>/dev/null | grep rawvideo || { echo "board: ffmpeg missing rawvideo"; exit 1; }'

cat <<'EOF'

Board OK. Next:
  ./stop_edgeeye_stack.sh && ./run_edgeeye_stack.sh
  cat /root/web/status.json    # expect "web_live":"hls"
  ls /root/web/hls/
EOF
