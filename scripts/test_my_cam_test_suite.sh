#!/bin/sh
# test_my_cam_test_suite.sh — 板上 my_cam_test 一键验收矩阵
#
# 用法：
#   ./test_my_cam_test_suite.sh                          # smoke：单摄 gc2083(2,3) + 双摄(3)
#   ./test_my_cam_test_suite.sh --profile full           # 单摄 gc2083 全阶段 + 双摄统一 2～5
#   ./test_my_cam_test_suite.sh --profile single --phases 2,3,4,5
#   ./test_my_cam_test_suite.sh --profile dual --phases 3,4
#   ./test_my_cam_test_suite.sh --profile dual-legacy    # phase 6/7/8 旧脚本
#   ./test_my_cam_test_suite.sh --list
#
# 环境变量：
#   MY_CAM_TEST      二进制路径（默认 /root/my_cam_test）
#   MY_CAM_CONTINUE  1=失败后继续
#   MY_CAM_REBOOT    1=单摄→双摄切换前 reboot（suite 内，仅板上直接跑时有效）
set -e

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$DIR/my_cam_test_common.sh"

PROFILE=smoke
PHASES=""
CONTINUE="${MY_CAM_CONTINUE:-0}"
REBOOT_BETWEEN="${MY_CAM_REBOOT:-0}"

usage() {
	cat <<'EOF'
Usage: test_my_cam_test_suite.sh [options]

Profiles:
  smoke        single gc2083 p2,p3 + dual unified p3 (default)
  single       single gc2083 phases 2-5
  single-all   single gc2083 + ov5647 phases 2-5
  dual         dual unified phases 2-5
  dual-legacy  dual phases 6,7,8 (backward-compat scripts)
  full         single gc2083 2-5 + dual unified 2-5 + dual-legacy 6-8

Options:
  --profile NAME
  --phases LIST     comma-separated, e.g. 2,3,4,5
  --continue        keep going after a failed case
  --reboot          reboot between major profile blocks (on board)
  --list            show profiles and exit
  -h, --help
EOF
}

list_profiles() {
	usage
}

while [ $# -gt 0 ]; do
	case "$1" in
	--profile)
		PROFILE="$2"
		shift 2
		;;
	--phases)
		PHASES="$2"
		shift 2
		;;
	--continue)
		CONTINUE=1
		shift
		;;
	--reboot)
		REBOOT_BETWEEN=1
		shift
		;;
	--list)
		list_profiles
		exit 0
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		echo "unknown option: $1"
		usage
		exit 1
		;;
	esac
done

my_cam_assert_bin || exit 1
my_cam_install_sensor_configs

SUITE_PASS=0
SUITE_FAIL=0
SUITE_START=$(date +%s 2>/dev/null || echo 0)

run_case() {
	name="$1"
	shift

	echo ""
	echo "##############################################"
	echo "# CASE: $name"
	echo "##############################################"

	if "$@"; then
		SUITE_PASS=$((SUITE_PASS + 1))
		echo ">>> CASE PASS: $name"
		return 0
	fi

	SUITE_FAIL=$((SUITE_FAIL + 1))
	echo ">>> CASE FAIL: $name"
	if [ "$CONTINUE" != 1 ]; then
		echo "suite aborted (use --continue to keep going)"
		exit 1
	fi
	return 1
}

run_single_phase() {
	sensor="$1"
	phase="$2"
	case "$phase" in
	2) "$DIR/test_my_cam_test.sh" "$sensor" ;;
	3) "$DIR/test_my_cam_test_phase3.sh" "$sensor" ;;
	4) "$DIR/test_my_cam_test_phase4.sh" "$sensor" ;;
	5) "$DIR/test_my_cam_test_phase5.sh" "$sensor" ;;
	*) echo "unsupported single phase $phase"; return 1 ;;
	esac
}

run_single_block() {
	sensor="$1"
	phases_csv="$2"
	old_ifs=$IFS
	IFS=,
	for phase in $phases_csv; do
		phase=$(echo "$phase" | tr -d ' ')
		[ -n "$phase" ] || continue
		run_case "single-$sensor-p$phase" run_single_phase "$sensor" "$phase"
	done
	IFS=$old_ifs
}

run_dual_unified_block() {
	phases_csv="$1"
	old_ifs=$IFS
	IFS=,
	for phase in $phases_csv; do
		phase=$(echo "$phase" | tr -d ' ')
		[ -n "$phase" ] || continue
		run_case "dual-unified-p$phase" "$DIR/test_my_cam_test_dual.sh" "$phase"
	done
	IFS=$old_ifs
}

run_dual_legacy_block() {
	phases_csv="${1:-6,7,8}"
	old_ifs=$IFS
	IFS=,
	for phase in $phases_csv; do
		phase=$(echo "$phase" | tr -d ' ')
		[ -n "$phase" ] || continue
		run_case "dual-legacy-p$phase" "$DIR/test_my_cam_test_phase.sh" "$phase"
	done
	IFS=$old_ifs
}

maybe_reboot() {
	if [ "$REBOOT_BETWEEN" = 1 ]; then
		echo "rebooting before next block..."
		reboot
	fi
}

# 默认 phase 列表（可被 --phases 覆盖）
default_phases() {
	case "$PROFILE" in
	smoke) echo "2,3" ;;
	single|single-all) echo "2,3,4,5" ;;
	dual) echo "2,3,4,5" ;;
	dual-legacy) echo "6,7,8" ;;
	full) echo "2,3,4,5" ;;
	*) echo "2,3,4,5" ;;
	esac
}

PHASES="${PHASES:-$(default_phases)}"

echo "=== my_cam_test suite profile=$PROFILE phases=$PHASES continue=$CONTINUE ==="

case "$PROFILE" in
smoke)
	run_single_block gc2083 "2,3"
	maybe_reboot
	run_dual_unified_block "3"
	;;
single)
	run_single_block gc2083 "$PHASES"
	;;
single-all)
	run_single_block gc2083 "$PHASES"
	maybe_reboot
	run_single_block ov5647 "$PHASES"
	;;
dual)
	run_dual_unified_block "$PHASES"
	;;
dual-legacy)
	run_dual_legacy_block "$PHASES"
	;;
full)
	run_single_block gc2083 "$PHASES"
	maybe_reboot
	run_dual_unified_block "$PHASES"
	maybe_reboot
	run_dual_legacy_block "6,7,8"
	;;
*)
	echo "unknown profile: $PROFILE"
	usage
	exit 1
	;;
esac

SUITE_END=$(date +%s 2>/dev/null || echo 0)
ELAPSED=$((SUITE_END - SUITE_START))

echo ""
echo "=============================================="
echo " Suite summary: $SUITE_PASS passed, $SUITE_FAIL failed (${ELAPSED}s)"
echo " profile=$PROFILE phases=$PHASES"
echo "=============================================="

if [ "$SUITE_FAIL" -ne 0 ]; then
	exit 1
fi

echo "=== SUITE PASSED ==="
