#!/bin/sh
# test_06_golden_logs.sh — 用 fixture 日志验证验收 grep 模式（无需板子）
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
FIX="$DIR/fixtures"

. "$DIR/lib_assert.sh"

echo "=== test_06_golden_logs ==="

check_log() {
	log="$1"
	shift
	for pat in "$@"; do
		assert_grep_file "$pat" "$log"
	done
}

assert_file "$FIX/phase2_gc2083_pass.log"
check_log "$FIX/phase2_gc2083_pass.log" \
	'GC2083' 'Init OK' 'PASSED (phase 2)'

assert_file "$FIX/phase6_dual_pass.log"
check_log "$FIX/phase6_dual_pass.log" \
	'dev_num=2' 'GC2083' 'OV5647' 'Init OK' \
	'PQ loaded pipe0' 'PQ loaded pipe1' \
	'dual ISP OK' 'dual VI/ISP OK' 'PASSED (phase 6)'

assert_file "$FIX/phase7_dual_pass.log"
check_log "$FIX/phase7_dual_pass.log" \
	'dual VPSS capture OK' 'saved' 'NV12' 'PASSED (phase 7)'

assert_file "$FIX/phase8_dual_pass.log"
check_log "$FIX/phase8_dual_pass.log" \
	'start save from IDR' 'dual VENC capture OK' 'PASSED (phase 8)'

test_summary
