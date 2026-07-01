#!/bin/sh
# record_clip.sh — 手动或脚本触发 RTSP H.264 录像（ffmpeg copy）
#
# 用法：./record_clip.sh [seconds] [cam_tag]
# 示例：./record_clip.sh 10 cam0
set -e

SEC="${1:-30}"
TAG="${2:-cam0}"
CLIP_DIR="${CLIP_DIR:-/mnt/sd/clips}"
RTSP_PORT="${RTSP_PORT:-8554}"

if [ -f /root/media_tools.sh ]; then
    # shellcheck disable=SC1091
    . /root/media_tools.sh
fi
FFMPEG="${FFMPEG:-ffmpeg}"

if [ ! -d "$CLIP_DIR" ]; then
    mkdir -p "$CLIP_DIR" 2>/dev/null || CLIP_DIR=/mnt/data/clips
    mkdir -p "$CLIP_DIR"
fi

if ! command -v "$FFMPEG" >/dev/null 2>&1 && [ ! -x "$FFMPEG" ]; then
    echo "record_clip: ffmpeg not found on board"
    echo "  PC preview: ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/${TAG}"
    echo "  PC record:  ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/${TAG} -c copy -t ${SEC} clip.mp4"
    echo "  Optional: copy static ffmpeg to /mnt/data/bin/ffmpeg from SDK OSS build"
    exit 1
fi

OUT="$CLIP_DIR/$(date +%s)_${TAG}.mp4"
URL="rtsp://127.0.0.1:${RTSP_PORT}/${TAG}"

echo "recording $SEC s from $URL -> $OUT"
"$FFMPEG" -y -loglevel warning -rtsp_transport tcp \
    -i "$URL" -c copy -t "$SEC" "$OUT"
echo "saved: $OUT"
