#!/bin/sh
# run_e2e.sh — Mac 一键：编译 → 部署 → 板上跑 my_cam_test 验收矩阵
#
# 用法（仓库根目录）：
#   tests/camera/run_e2e.sh
#   tests/camera/run_e2e.sh --profile full --reboot
#   tests/camera/run_e2e.sh --no-build --profile dual --phases 3,4
#   make test-e2e
#
# 环境变量：
#   BOARD_IP=192.168.42.1
#   DOCKER_IMAGE=milkvtech/milkv-duo:latest
#   WORK_MOUNT=/path/to/riscv   默认自动探测（含 edgeeye-duos 的父目录）
#   MY_CAM_CONTINUE=1           传给板上 suite
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/tests/camera"
. "$DIR/lib_board.sh"

DO_BUILD=1
DO_DEPLOY=1
DO_REBOOT=0
DO_RUN=1
FETCH_ON_FAIL=1
PROFILE=smoke
PHASES=""
CONTINUE="${MY_CAM_CONTINUE:-0}"
DOCKER_IMAGE="${DOCKER_IMAGE:-milkvtech/milkv-duo:latest}"
WORK_MOUNT="${WORK_MOUNT:-$(CDPATH= cd -- "$ROOT/.." && pwd)}"

usage() {
	cat <<'EOF'
Usage: run_e2e.sh [options]

  --profile NAME     smoke|single|single-all|dual|dual-legacy|full (default smoke)
  --phases LIST      e.g. 2,3,4,5 (forwarded to board suite)
  --reboot           reboot board before suite
  --no-build         skip compile
  --no-deploy        skip scp deploy
  --build-only       compile then exit
  --deploy-only      deploy then exit
  --continue         keep suite running after failure
  --no-fetch         do not scp logs on failure
  -h, --help
EOF
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
	--reboot)
		DO_REBOOT=1
		shift
		;;
	--no-build)
		DO_BUILD=0
		shift
		;;
	--no-deploy)
		DO_DEPLOY=0
		shift
		;;
	--build-only)
		DO_BUILD=1
		DO_DEPLOY=0
		DO_RUN=0
		shift
		;;
	--deploy-only)
		DO_BUILD=0
		DO_DEPLOY=1
		DO_RUN=0
		shift
		;;
	--continue)
		CONTINUE=1
		shift
		;;
	--no-fetch)
		FETCH_ON_FAIL=0
		shift
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

echo "=============================================="
echo " EdgeEye camera E2E"
echo " board=$BOARD_USER@$BOARD_IP profile=$PROFILE"
echo " build=$DO_BUILD deploy=$DO_DEPLOY run=$DO_RUN reboot=$DO_REBOOT"
echo "=============================================="

if [ "$DO_BUILD" = 1 ]; then
	if command -v docker >/dev/null 2>&1; then
		echo ">>> docker build (make app)"
		docker run --rm --platform linux/amd64 \
			-v "$WORK_MOUNT:/home/work" \
			"$DOCKER_IMAGE" \
			bash -lc 'source /home/work/init_env.sh && cd /home/work/edgeeye-duos && make app'
	else
		echo ">>> local make app"
		if ! command -v riscv64-unknown-linux-musl-gcc >/dev/null 2>&1; then
			echo "FAIL: no cross gcc and no docker"
			exit 1
		fi
		(cd "$ROOT" && make app)
	fi
fi

if [ "$DO_DEPLOY" = 1 ]; then
	if ! board_ping; then
		echo "FAIL: board unreachable at $BOARD_IP"
		exit 1
	fi
	echo ">>> deploy"
	"$ROOT/deploy"
	board_install_sensor_configs
	chmod +x "$ROOT/scripts/test_my_cam_test"*.sh "$ROOT/scripts/my_cam_test_common.sh" 2>/dev/null || true
	board_ssh "chmod +x $BOARD_DIR/test_my_cam_test*.sh $BOARD_DIR/my_cam_test_common.sh"
fi

if [ "$DO_RUN" = 0 ]; then
	echo ">>> done (no remote suite)"
	exit 0
fi

if ! board_ping; then
	echo "FAIL: board unreachable at $BOARD_IP"
	exit 1
fi

if [ "$DO_REBOOT" = 1 ]; then
	board_reboot_and_wait
fi

REMOTE_CMD="$BOARD_DIR/test_my_cam_test_suite.sh --profile $PROFILE"
if [ -n "$PHASES" ]; then
	REMOTE_CMD="$REMOTE_CMD --phases $PHASES"
fi
if [ "$CONTINUE" = 1 ]; then
	REMOTE_CMD="$REMOTE_CMD --continue"
fi

echo ">>> remote: $REMOTE_CMD"
set +e
board_ssh "cd $BOARD_DIR && $REMOTE_CMD"
RC=$?
set -e

if [ "$RC" -ne 0 ] && [ "$FETCH_ON_FAIL" = 1 ]; then
	board_fetch_logs_on_fail "/tmp/edgeeye_cam_logs_$(date +%Y%m%d_%H%M%S 2>/dev/null || echo fail)"
fi

if [ "$RC" -ne 0 ]; then
	echo "=== E2E FAILED (rc=$RC) ==="
	exit "$RC"
fi

echo "=== E2E PASSED ==="
