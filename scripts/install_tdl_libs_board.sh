#!/bin/sh
# install_tdl_libs_board.sh — 部署板上 sample_img_det 缺失的 TDL 库
#
# 从 duo-sdk tdl_sdk/install/lib 拷贝 libcvi_tdl_app.so 到板子 /mnt/system/lib/
#
# 用法（Mac / Docker 宿主机，板子 USB 可达）：
#   cd edgeeye-duos && ./scripts/install_tdl_libs_board.sh
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"
EDGEEYE_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DUO_SDK_ROOT="${DUO_SDK_ROOT:-$(cd "$EDGEEYE_ROOT/../duo-sdk" 2>/dev/null && pwd)}"

LIB_SRC="${DUO_SDK_ROOT}/tdl_sdk/install/lib/libcvi_tdl_app.so"
if [ ! -f "$LIB_SRC" ]; then
	echo "missing $LIB_SRC"
	echo "  set DUO_SDK_ROOT or build tdl_sdk in duo-sdk"
	exit 1
fi

echo "deploy $LIB_SRC -> ${BOARD_USER}@${BOARD_IP}:/mnt/system/lib/"
ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_IP" \
	"mkdir -p /mnt/system/lib"
scp -o ConnectTimeout=8 -o StrictHostKeyChecking=no \
	"$LIB_SRC" "$BOARD_USER@$BOARD_IP:/mnt/system/lib/libcvi_tdl_app.so"
ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_IP" \
	"chmod 755 /mnt/system/lib/libcvi_tdl_app.so && ls -la /mnt/system/lib/libcvi_tdl_app.so"

echo "done. LD_LIBRARY_PATH should include /mnt/system/lib"
echo "test: ./scripts/check_ai_person_detect_board.sh"
