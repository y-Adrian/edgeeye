#!/bin/sh
# media_tools.sh — 查找板上 ffmpeg 等工具（stock rootfs 通常不含 ffmpeg）
#
# 用法：. /root/media_tools.sh && echo "$FFMPEG"

find_ffmpeg() {
    for p in "$FFMPEG" ffmpeg /usr/bin/ffmpeg /usr/local/bin/ffmpeg \
             /mnt/system/usr/bin/ffmpeg /mnt/data/bin/ffmpeg; do
        [ -n "$p" ] || continue
        if command -v "$p" >/dev/null 2>&1; then
            command -v "$p"
            return 0
        fi
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

resolve_ffmpeg() {
    FFMPEG="$(find_ffmpeg 2>/dev/null)" || FFMPEG=
    export FFMPEG
}

resolve_ffmpeg
