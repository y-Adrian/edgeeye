#!/bin/sh
# run_board_tests.sh — 板上 my_cam_test 冒烟（Mac SSH 调度）
#
# 用法：
#   ./tests/camera/run_board_tests.sh            # smoke（快）
#   ./tests/camera/run_board_tests.sh all        # full 全矩阵（等同旧版串联 2～8）
#   ./tests/camera/run_board_tests.sh 7          # 仅 legacy phase 7
#   ./tests/camera/run_board_tests.sh --profile dual --phases 3,4
#
# 推荐一键：tests/camera/run_e2e.sh（含 build + deploy）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
E2E="$ROOT/tests/camera/run_e2e.sh"

run_e2e() {
	"$E2E" --no-build --no-deploy "$@"
}

case "${1:-}" in
""|smoke)
	[ "$1" = smoke ] && shift
	run_e2e --profile smoke "$@"
	;;
all|full)
	shift 2>/dev/null || true
	run_e2e --profile full "$@"
	;;
2|3|4|5)
	phase="$1"
	shift
	run_e2e --profile single --phases "$phase" "$@"
	;;
6|7|8)
	phase="$1"
	shift
	run_e2e --profile dual-legacy --phases "$phase" "$@"
	;;
--profile|--phases|--reboot|--continue|--no-fetch|-h|--help)
	run_e2e "$@"
	;;
*)
	echo "usage: $0 [smoke|all|2-8|--profile NAME ...]"
	echo "  full pipeline: tests/camera/run_e2e.sh"
	exit 1
	;;
esac
