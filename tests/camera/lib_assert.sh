# lib_assert.sh — 本地测试小工具（须 source，勿直接执行）

TESTS_RUN=0
TESTS_FAIL=0

assert_eq() {
	TESTS_RUN=$((TESTS_RUN + 1))
	if [ "$1" != "$2" ]; then
		echo "  FAIL: expected '$2', got '$1'"
		TESTS_FAIL=$((TESTS_FAIL + 1))
		return 1
	fi
	echo "  ok: $3"
	return 0
}

assert_match() {
	TESTS_RUN=$((TESTS_RUN + 1))
	if ! echo "$2" | grep -q "$1"; then
		echo "  FAIL: pattern '$1' not in: $2"
		TESTS_FAIL=$((TESTS_FAIL + 1))
		return 1
	fi
	echo "  ok: $3"
	return 0
}

assert_file() {
	TESTS_RUN=$((TESTS_RUN + 1))
	if [ ! -f "$1" ]; then
		echo "  FAIL: missing file $1"
		TESTS_FAIL=$((TESTS_FAIL + 1))
		return 1
	fi
	echo "  ok: exists $1"
	return 0
}

assert_grep_file() {
	TESTS_RUN=$((TESTS_RUN + 1))
	if ! grep -e "$1" "$2" >/dev/null 2>&1; then
		echo "  FAIL: '$1' not in $2"
		TESTS_FAIL=$((TESTS_FAIL + 1))
		return 1
	fi
	echo "  ok: grep '$1' in $(basename "$2")"
	return 0
}

test_summary() {
	echo "---"
	if [ "$TESTS_FAIL" -eq 0 ]; then
		echo "PASS ($TESTS_RUN checks)"
		return 0
	fi
	echo "FAIL ($TESTS_FAIL of $TESTS_RUN checks failed)"
	return 1
}
