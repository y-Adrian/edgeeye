#!/bin/sh
# install_autostart.sh — 按 edgeeye_cam.conf 管理开机自启
#
# 用法：
#   ./install_autostart.sh          读取 conf 同步（autostart=0 移除，=1 安装）
#   ./install_autostart.sh sync     同上
#   ./install_autostart.sh enable   安装 init.d（不改 conf，临时启用）
#   ./install_autostart.sh disable  移除 init.d（不改 conf）
#   ./install_autostart.sh status   查看 conf 与 init.d 状态
#
# 持久配置：编辑 /root/edgeeye_cam.conf 中 autostart=0|1，再执行 ./install_autostart.sh
set -e

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/edgeeye_cam_common.sh"

usage() {
	cat <<'EOF'
Usage: install_autostart.sh [sync|enable|disable|status]

  sync     按 edgeeye_cam.conf 的 autostart=0|1 安装或移除（默认）
  enable   仅安装 /etc/init.d/S99edgeeye_cam（不修改 conf）
  disable  仅移除 init 脚本（不修改 conf）
  status   打印 conf 与 init.d 状态

改 conf 后执行 sync；Web/录像开关在 conf 的 web= / record=，改后 restart 栈即可。
EOF
}

case "${1:-sync}" in
sync)
	edgeeye_apply_autostart
	;;
enable)
	edgeeye_autostart_install
	echo "tip: set autostart=1 in $EDGEEYE_CONF and run sync to persist across redeploy"
	;;
disable)
	edgeeye_autostart_remove
	echo "tip: set autostart=0 in $EDGEEYE_CONF and run sync to persist"
	;;
status)
	edgeeye_autostart_status
	;;
-h|--help)
	usage
	;;
*)
	echo "unknown: $1" >&2
	usage
	exit 1
	;;
esac
