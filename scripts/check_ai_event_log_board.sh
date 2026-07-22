#!/bin/sh
# check_ai_event_log_board.sh — 板上验证 ai_event_log 本地日志
set -e

BOARD_IP="${BOARD_IP:-192.168.42.1}"
BOARD_USER="${BOARD_USER:-root}"

ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no "$BOARD_USER@$BOARD_IP" '
set -e
BIN=/root/ai_event_log
[ -x "$BIN" ] || { echo "missing $BIN — deploy ai_event_log"; exit 1; }

LOGDIR=/tmp/edgeeye_ai_test_events
rm -rf "$LOGDIR"
"$BIN" --dry-run --log-dir "$LOGDIR"
"$BIN" --inject person --score 0.87 --cam cam0 --log-dir "$LOGDIR" --source inject
test -f "$LOGDIR/events.ndjson"
tail -1 "$LOGDIR/events.ndjson" | grep -q "\"class\":\"person\""
tail -1 "$LOGDIR/events.ndjson" | grep -q "0.8700"
echo "=== last event ==="
tail -1 "$LOGDIR/events.ndjson"
echo "=== ai_event_log board OK ==="
'
