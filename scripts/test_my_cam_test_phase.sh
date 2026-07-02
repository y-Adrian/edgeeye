#!/bin/sh
# test_my_cam_test_phase.sh — 按阶段 + 传感器验收 my_cam_test
#
# 用法：
#   ./test_my_cam_test_phase.sh <2|3|4|5|6> [gc2083|ov5647]
#
# 须与 my_cam_test_common.sh、test_my_cam_test*.sh 放在同一目录。
# 板上部署：scp scripts/test_my_cam_test*.sh scripts/my_cam_test_common.sh root@192.168.42.1:/root/
set -e

PHASE="${1:-}"
SENSOR="${2:-gc2083}"
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

case "$PHASE" in
2|3|4|5|6) ;;
*)
	echo "usage: $0 <2|3|4|5|6> [gc2083|ov5647]"
	echo "  gc2083 = J1 Milk-V CAM-GC2083"
	echo "  ov5647 = J2 树莓派 OV5647"
	echo "  phase 6 = dual (mixed ini, no sensor arg)"
	exit 1
	;;
esac

if [ "$PHASE" = 6 ]; then
	CHILD="$DIR/test_my_cam_test_phase6.sh"
elif [ "$PHASE" = 2 ]; then
	CHILD="$DIR/test_my_cam_test.sh"
else
	CHILD="$DIR/test_my_cam_test_phase${PHASE}.sh"
fi

COMMON="$DIR/my_cam_test_common.sh"
if [ ! -f "$COMMON" ]; then
	echo "missing $COMMON"
	echo "copy scripts/my_cam_test_common.sh next to this script"
	exit 1
fi
if [ ! -x "$CHILD" ]; then
	echo "missing $CHILD"
	echo "copy all scripts/test_my_cam_test*.sh to the same directory as $0"
	exit 1
fi

exec "$CHILD" ${SENSOR:+"$SENSOR"}
