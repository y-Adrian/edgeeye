#!/bin/sh
# install_ffprobe_board.sh — 从 SDK OSS 安装 ffprobe 到板子（无 ffmpeg CLI）
#
# 说明：duo-sdk 预编译 ffmpeg.tar.gz 仅含 libav* + ffprobe，不含 ffmpeg/ffplay。
# 用法（Docker 内）：
#   source duo-sdk/build/envsetup_milkv.sh sg2000_milkv_duos_musl_riscv64_sd
#   cd /home/work/Camera && ./scripts/install_ffprobe_board.sh
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
WORK_ROOT="${WORK_ROOT:-/home/work}"

SDK_TAR="$WORK_ROOT/duo-sdk/install/soc_sg2000_milkv_duos_musl_riscv64_sd/tpu_musl_riscv64/third_party/ffmpeg.tar.gz"
TPU_FFPROBE="$WORK_ROOT/duo-sdk/install/soc_sg2000_milkv_duos_musl_riscv64_sd/tpu_musl_riscv64/cvitek_tpu_sdk/bin/ffprobe"
STAGE="/tmp/debris_ffmpeg_stage"

if [ ! -f "$SDK_TAR" ]; then
    echo "missing $SDK_TAR — run: build_3rd_party"
    exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/lib" "$STAGE/bin"

tar -xzf "$SDK_TAR" -C "$STAGE"
if [ ! -f "$STAGE/bin/ffprobe" ] && [ -f "$TPU_FFPROBE" ]; then
    cp "$TPU_FFPROBE" "$STAGE/bin/ffprobe"
fi

if [ ! -f "$STAGE/bin/ffprobe" ]; then
    echo "ffprobe not found in tarball"
    exit 1
fi

file "$STAGE/bin/ffprobe"
echo "note: SDK ffmpeg package has NO ffmpeg/ffplay binary — only ffprobe + libs"

ssh "$BOARD_USER@$BOARD_IP" "mkdir -p /mnt/data/bin /mnt/data/lib"
scp "$STAGE/bin/ffprobe" "$BOARD_USER@$BOARD_IP:/mnt/data/bin/ffprobe"
scp "$STAGE"/lib/libav*.so* "$STAGE"/lib/libswresample.so* \
    "$BOARD_USER@$BOARD_IP:/mnt/data/lib/" 2>/dev/null || true

ssh "$BOARD_USER@$BOARD_IP" "chmod +x /mnt/data/bin/ffprobe"

cat <<'EOF'

Installed on board:
  /mnt/data/bin/ffprobe
  /mnt/data/lib/libav*.so*

Board test:
  export LD_LIBRARY_PATH=/mnt/data/lib:$LD_LIBRARY_PATH
  /mnt/data/bin/ffprobe -rtsp_transport tcp -show_streams rtsp://127.0.0.1:8554/cam0

Recording still needs ffmpeg CLI — use PC or run:
  ./scripts/build_ffmpeg_cli.sh
EOF
