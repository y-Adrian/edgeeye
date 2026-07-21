#!/bin/sh
# test_11_wifi_docs.sh — WiFi 文档与脚本存在性检查（宿主机）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_assert.sh"

echo "=== test_11_wifi_docs ==="

assert_file "$ROOT/docs/WIFI.md"
assert_file "$ROOT/configs/wpa_supplicant.conf.example"
assert_file "$ROOT/scripts/setup_wifi_board.sh"
assert_file "$ROOT/scripts/check_wifi_board.sh"
assert_grep_file 'WPA-PSK' "$ROOT/configs/wpa_supplicant.conf.example"
assert_grep_file 'YOUR_WIFI_SSID' "$ROOT/configs/wpa_supplicant.conf.example"
assert_grep_file 'setup_wifi_board' "$ROOT/docs/WIFI.md"
assert_grep_file 'check_wifi_board' "$ROOT/docs/WIFI.md"
assert_grep_file 'udhcpc' "$ROOT/scripts/setup_wifi_board.sh"
assert_grep_file '8.8.8.8' "$ROOT/scripts/check_wifi_board.sh"
assert_grep_file 'YOUR_WIFI_PASSWORD' "$ROOT/configs/wpa_supplicant.conf.example"

test_summary
