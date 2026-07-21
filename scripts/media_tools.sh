#!/bin/sh
# media_tools.sh — 查找板上 ffmpeg 等工具（stock rootfs 通常不含 ffmpeg）
#
# 用法：. /root/media_tools.sh && echo "$FFMPEG"

find_ffmpeg() {
    for p in /mnt/data/bin/ffmpeg /mnt/system/usr/bin/ffmpeg \
             /usr/bin/ffmpeg /usr/local/bin/ffmpeg; do
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    if command -v ffmpeg >/dev/null 2>&1; then
        command -v ffmpeg
        return 0
    fi
    case "$FFMPEG" in
    /*)
        if [ -x "$FFMPEG" ]; then
            echo "$FFMPEG"
            return 0
        fi
        ;;
    esac
    return 1
}

resolve_ffmpeg() {
    FFMPEG="$(find_ffmpeg 2>/dev/null)" || FFMPEG=
    export FFMPEG
}

resolve_ffmpeg
