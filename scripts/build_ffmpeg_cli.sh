#!/bin/sh
# build_ffmpeg_cli.sh — 交叉编译静态 ffmpeg（riscv64 musl）供板上 RTSP 录像 / Web 快照
#
# 用法（Docker 内，约 10–20 分钟）：
#   cd edgeeye-duos && source scripts/envsetup.sh
#   ./scripts/build_ffmpeg_cli.sh
#   ./scripts/install_ffmpeg_cli_board.sh
#
# Duo S 工具链（binutils 2.35 / C906）不支持 FFmpeg 6.x 的 RISC-V Zbb 汇编（rev8），
# 须 --disable-asm --disable-rvv（与 duo-sdk buildroot ffmpeg.mk 一致）。
#
# 产出：/tmp/debris_ffmpeg_out/bin/ffmpeg（静态链接）
set -e

EDGEEYE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUO_SDK_ROOT="${DUO_SDK_ROOT:-$(cd "$EDGEEYE_ROOT/../duo-sdk" 2>/dev/null && pwd)}"

FFVER="${FFVER:-6.1.1}"
SRC="/tmp/ffmpeg-${FFVER}"
OUT="/tmp/debris_ffmpeg_out"
TARBALL="/tmp/ffmpeg-${FFVER}.tar.xz"
URL="https://ffmpeg.org/releases/ffmpeg-${FFVER}.tar.xz"

: "${CROSS_COMPILE:?source scripts/envsetup.sh first}"

CC="${CROSS_COMPILE}gcc"
AR="${CROSS_COMPILE}ar"
RANLIB="${CROSS_COMPILE}ranlib"
STRIP="${CROSS_COMPILE}strip"

echo "=== build static ffmpeg ${FFVER} for riscv64 musl ==="
echo "CC=$CC"

if [ ! -f "$TARBALL" ]; then
    echo "downloading $URL"
    wget -q -O "$TARBALL" "$URL" || curl -L -o "$TARBALL" "$URL"
fi

rm -rf "$SRC"
tar -xf "$TARBALL" -C /tmp
rm -rf "$OUT"
mkdir -p "$OUT"

cd "$SRC"
./configure \
    --prefix="$OUT" \
    --arch=riscv64 \
    --target-os=linux \
    --cc="$CC" \
    --ar="$AR" \
    --ranlib="$RANLIB" \
    --strip="$STRIP" \
    --enable-cross-compile \
    --enable-static \
    --disable-shared \
    --disable-debug \
    --disable-doc \
    --enable-ffmpeg \
    --enable-ffprobe \
    --disable-ffplay \
    --disable-everything \
    --disable-asm \
    --disable-rvv \
    --enable-protocol=file \
    --enable-protocol=rtsp \
    --enable-protocol=tcp \
    --enable-demuxer=rtsp \
    --enable-muxer=mp4 \
    --enable-muxer=mov \
    --enable-muxer=image2 \
    --enable-parser=h264 \
    --enable-decoder=h264 \
    --enable-encoder=mjpeg \
    --enable-filter=scale \
    --enable-filter=format \
    --extra-cflags="-Os -march=rv64imafdc -mabi=lp64d" \
    --extra-ldflags="-static"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

file "$OUT/bin/ffmpeg"
ls -lh "$OUT/bin/ffmpeg"
echo ""
echo "done: $OUT/bin/ffmpeg"
echo "next: ./scripts/install_ffmpeg_cli_board.sh"
