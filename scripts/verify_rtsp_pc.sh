#!/bin/sh
# verify_rtsp_pc.sh — 在 PC/Mac 上验证 RTSP 拉流（板上 verify_board.sh 之后运行）
#
# 用法：./verify_rtsp_pc.sh [board_ip]
set -e

IP="${1:-192.168.42.1}"
URL="rtsp://${IP}:8554/cam0"

echo "=== RTSP PC verify ==="
echo "URL: $URL"

if command -v ffprobe >/dev/null 2>&1; then
    echo "--- ffprobe ---"
    if ffprobe -rtsp_transport tcp -v error -show_entries stream=codec_name,width,height \
        -of default=nw=1 "$URL" 2>&1; then
        echo "[PASS] ffprobe sees stream"
    else
        echo "[FAIL] ffprobe cannot reach $URL"
        exit 1
    fi
else
    echo "[SKIP] ffprobe not installed"
fi

if command -v ffmpeg >/dev/null 2>&1; then
    OUT="/tmp/debris_cam0_test.mp4"
    echo "--- ffmpeg 5s clip -> $OUT ---"
    ffmpeg -y -loglevel warning -rtsp_transport tcp -i "$URL" -c copy -t 5 "$OUT"
    if [ -f "$OUT" ] && [ -s "$OUT" ]; then
        echo "[PASS] saved $OUT ($(wc -c < "$OUT") bytes)"
    else
        echo "[FAIL] clip empty"
        exit 1
    fi
else
    echo "[SKIP] ffmpeg not installed"
fi

echo "=== done ==="
