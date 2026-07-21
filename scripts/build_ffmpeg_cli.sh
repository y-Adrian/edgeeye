#!/bin/sh
# build_ffmpeg_cli.sh — 交叉编译静态 ffmpeg（riscv64 musl）
# 用途：RTSP 录像 / 动检 JPEG / Web 快照 / HLS remux（-c copy）
#
# 用法（Docker 内，约 10–20 分钟）：
#   cd edgeeye-duos && source scripts/envsetup.sh
#   ./scripts/build_ffmpeg_cli.sh
#   ./scripts/install_ffmpeg_cli_board.sh
#
# Duo S 工具链（binutils 2.35 / C906）不支持 FFmpeg 6.x 的 RISC-V Zbb 汇编（rev8），
# 须 --disable-asm --disable-rvv（与 duo-sdk buildroot ffmpeg.mk 一致）。
#
# 产出：
#   output/ffmpeg-riscv64-static  （持久化，供 ./deploy / install_ffmpeg_cli_board.sh）
#   /tmp/debris_ffmpeg_out/bin/ffmpeg（同次构建副本，容器内临时路径）
# 板端自检 HLS：/mnt/data/bin/ffmpeg -muxers | grep hls
set -e

EDGEEYE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_OUT="$EDGEEYE_ROOT/output/ffmpeg-riscv64-static"
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
    --enable-muxer=hls \
    --enable-muxer=mpegts \
    --enable-parser=h264 \
    --enable-decoder=h264 \
    --enable-encoder=mjpeg \
    --enable-bsf=h264_mp4toannexb \
    --enable-filter=scale \
    --enable-filter=format \
    --extra-cflags="-Os -march=rv64imafdc -mabi=lp64d" \
    --extra-ldflags="-static"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

file "$OUT/bin/ffmpeg"
ls -lh "$OUT/bin/ffmpeg"

mkdir -p "$EDGEEYE_ROOT/output"
cp -f "$OUT/bin/ffmpeg" "$STAGE_OUT"
chmod +x "$STAGE_OUT"

if ! "$STAGE_OUT" -hide_banner -muxers 2>/dev/null | grep -qE '[[:space:]]hls[[:space:]]'; then
	echo "ERROR: staged ffmpeg missing HLS muxer" >&2
	exit 1
fi

echo ""
echo "done:"
echo "  $STAGE_OUT          (deploy / install 使用此文件)"
echo "  $OUT/bin/ffmpeg     (容器 /tmp 副本)"
echo ""
echo "next:"
echo "  ./deploy                              # 或"
echo "  ./scripts/install_ffmpeg_cli_board.sh"
