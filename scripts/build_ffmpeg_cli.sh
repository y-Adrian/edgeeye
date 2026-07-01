#!/bin/sh
# build_ffmpeg_cli.sh — 交叉编译静态 ffmpeg（riscv64 musl）供板上 RTSP 录像
#
# 用法（Docker 内，约 10–20 分钟）：
#   source /home/work/duo-sdk/build/envsetup_milkv.sh sg2000_milkv_duos_musl_riscv64_sd
#   cd /home/work/Camera && ./scripts/build_ffmpeg_cli.sh
#   ./scripts/install_ffmpeg_cli_board.sh
#
# 产出：/tmp/debris_ffmpeg_out/bin/ffmpeg（静态链接）
set -e

WORK_ROOT="${WORK_ROOT:-/home/work}"
FFVER="${FFVER:-6.1.1}"
SRC="/tmp/ffmpeg-${FFVER}"
OUT="/tmp/debris_ffmpeg_out"
TARBALL="/tmp/ffmpeg-${FFVER}.tar.xz"
URL="https://ffmpeg.org/releases/ffmpeg-${FFVER}.tar.xz"

: "${CROSS_COMPILE:?set envsetup first}"

CC="${CROSS_COMPILE}gcc"
AR="${CROSS_COMPILE}ar"
RANLIB="${CROSS_COMPILE}ranlib"

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
    --enable-cross-compile \
    --enable-static \
    --disable-shared \
    --disable-debug \
    --disable-doc \
    --enable-ffmpeg \
    --enable-ffprobe \
    --disable-ffplay \
    --disable-everything \
    --enable-protocol=file \
    --enable-protocol=rtsp \
    --enable-protocol=tcp \
    --enable-demuxer=rtsp \
    --enable-muxer=mp4 \
    --enable-muxer=mov \
    --enable-parser=h264 \
    --extra-cflags="-Os" \
    --extra-ldflags="-static"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

file "$OUT/bin/ffmpeg"
ls -lh "$OUT/bin/ffmpeg"
echo ""
echo "done: $OUT/bin/ffmpeg"
echo "next: ./scripts/install_ffmpeg_cli_board.sh"
