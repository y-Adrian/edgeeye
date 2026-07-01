#!/bin/sh
# install_ffmpeg_cli_board.sh — 部署静态 ffmpeg 到板子
#
# 前提：./scripts/build_ffmpeg_cli.sh 已生成 /tmp/debris_ffmpeg_out/bin/ffmpeg
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
FFMPEG="${FFMPEG_BIN:-/tmp/debris_ffmpeg_out/bin/ffmpeg}"

if [ ! -x "$FFMPEG" ]; then
    echo "missing $FFMPEG — run build_ffmpeg_cli.sh first"
    exit 1
fi

file "$FFMPEG"
ssh "$BOARD_USER@$BOARD_IP" "mkdir -p /mnt/data/bin"
scp "$FFMPEG" "$BOARD_USER@$BOARD_IP:/mnt/data/bin/ffmpeg"
ssh "$BOARD_USER@$BOARD_IP" "chmod +x /mnt/data/bin/ffmpeg"

cat <<'EOF'

Board test:
  /mnt/data/bin/ffmpeg -version
  /root/record_clip.sh 10 cam0
  /root/stop_security.sh && /root/run_security.sh   # motion_recorder 将启用

ffplay 仍无板载版本 — PC 预览：
  ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0
EOF
