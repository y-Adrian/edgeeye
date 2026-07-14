#!/bin/sh
# test_10_web_hls_config.sh — 浏览器 HLS 双路直播配置与脚本检查
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_10_web_hls_config ==="

CONF="$ROOT/configs/edgeeye_cam.conf"
COMMON="$ROOT/scripts/edgeeye_cam_common.sh"
HLS="$ROOT/scripts/edgeeye_hls.sh"
SRV="$ROOT/scripts/serve_edgeeye_web.sh"
HTTP="$ROOT/scripts/edgeeye_http_server.py"
WEB="$ROOT/web/index.html"
VENDOR="$ROOT/web/vendor/hls.min.js"
FFBUILD="$ROOT/scripts/build_ffmpeg_cli.sh"

assert_file "$CONF"
assert_file "$COMMON"
assert_file "$HLS"
assert_file "$SRV"
assert_file "$HTTP"
assert_file "$WEB"
assert_file "$VENDOR"

assert_grep_file 'web_live=hls' "$CONF"
assert_grep_file 'EDGEEYE_WEB_LIVE' "$COMMON"
assert_grep_file 'edgeeye_stop_hls' "$COMMON"
assert_grep_file 'muxer=hls' "$FFBUILD"
assert_grep_file 'hls_time' "$HLS"
assert_grep_file 'edgeeye_hls.sh' "$SRV"
assert_grep_file 'hls.min.js' "$WEB"
assert_grep_file 'hls/cam0.m3u8' "$WEB"
assert_grep_file 'application/vnd.apple.mpegurl' "$HTTP"

test_summary
