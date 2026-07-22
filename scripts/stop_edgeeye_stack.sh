#!/bin/sh
# stop_edgeeye_stack.sh — 停止 edgeeye 产品栈
set -e

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh" 2>/dev/null || true

edgeeye_stop_web
edgeeye_stop_ai
edgeeye_stop_recording
sh "$DIR/stop_my_cam_rtsp.sh" 2>/dev/null || true
echo "edgeeye stack stopped"
