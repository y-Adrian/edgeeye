#!/bin/sh
# verify_board.sh — Phase 6+ 板上用户态验收（test_debris 通过后的下一步）
#
# 用法：./verify_board.sh [quick|full]
#   quick — 不启停 run_security，只测独立项
#   full  — 先 stop → run_security → 验收 → 可选 stop
#
# 日志：/tmp/verify_board.log
set -e

MODE="${1:-full}"
LOG=/tmp/verify_board.log
PASS=0
FAIL=0
SKIP=0
ROOT=/root

log() { echo "$@" | tee -a "$LOG"; }

pass() { PASS=$((PASS + 1)); log "[PASS] $1"; }
fail() { FAIL=$((FAIL + 1)); log "[FAIL] $1"; }
skip() { SKIP=$((SKIP + 1)); log "[SKIP] $1"; }

run_case() {
    name="$1"
    shift
    log ""
    log "=== $name ==="
    if "$@"; then
        pass "$name"
        return 0
    fi
    fail "$name"
    return 1
}

: > "$LOG"
log "verify_board.sh mode=$MODE $(date)"

cd "$ROOT" || exit 1

# ── 前提 ─────────────────────────────────────────────────────
if ! lsmod | grep -q '^debris '; then
    log "loading debris.ko..."
    insmod "$ROOT/debris.ko" register_fallback_pdev=0 2>>"$LOG" || {
        fail "insmod debris.ko"
        exit 1
    }
fi

if [ "$MODE" = "full" ]; then
    if [ -x "$ROOT/stop_my_cam_rtsp.sh" ]; then
        sh "$ROOT/stop_my_cam_rtsp.sh" >>"$LOG" 2>&1 || true
    fi
    if [ -x "$ROOT/stop_security.sh" ]; then
        sh "$ROOT/stop_security.sh" >>"$LOG" 2>&1 || true
        sleep 1
    fi
    if [ -x "$ROOT/run_edgeeye_cam.sh" ] && [ -x "$ROOT/edgeeye_cam" ]; then
        log "starting run_edgeeye_cam.sh..."
        sh "$ROOT/run_edgeeye_cam.sh" >>"$LOG" 2>&1 || true
        sleep 5
    elif [ -x "$ROOT/run_security.sh" ]; then
        log "starting run_security.sh (legacy)..."
        sh "$ROOT/run_security.sh" >>"$LOG" 2>&1 || true
        sleep 3
    fi
fi

# TC-U01 motion_recorder dry-run
tc_u01() {
    [ -x "$ROOT/motion_recorder" ] || { skip "motion_recorder binary missing"; return 0; }
    "$ROOT/motion_recorder" --dry-run >>"$LOG" 2>&1
}

# TC-U03 health_check
tc_u03() {
    [ -x "$ROOT/health_check.sh" ] || return 1
    sh "$ROOT/health_check.sh" >>"$LOG" 2>&1
}

# TC-U04 dual camera ini setup
tc_u04() {
    [ -x "$ROOT/setup_dual_camera.sh" ] || return 1
    sh "$ROOT/setup_dual_camera.sh" >>"$LOG" 2>&1
    [ -L /mnt/data/sensor_cfg.ini ] || [ -f /mnt/data/sensor_cfg.ini ]
}

# TC-U06 sync_probe
tc_u06() {
    [ -x "$ROOT/sync_probe" ] || { skip "sync_probe missing"; return 0; }
    "$ROOT/sync_probe" >>"$LOG" 2>&1
    "$ROOT/sync_probe" dual >>"$LOG" 2>&1
}

# RTSP port / process
tc_rtsp() {
    if [ -f /tmp/edgeeye_cam_rtsp.pid ] && kill -0 "$(cat /tmp/edgeeye_cam_rtsp.pid)" 2>/dev/null; then
        log "edgeeye_cam pid $(cat /tmp/edgeeye_cam_rtsp.pid)"
        return 0
    fi
    if [ -f /tmp/rtsp_server.pid ] && kill -0 "$(cat /tmp/rtsp_server.pid)" 2>/dev/null; then
        log "rtsp_server pid $(cat /tmp/rtsp_server.pid)"
        return 0
    fi
    if netstat -ln 2>/dev/null | grep -q ':8554'; then
        return 0
    fi
    if ss -ln 2>/dev/null | grep -q ':8554'; then
        return 0
    fi
    return 1
}

# TC-U02 record_clip (needs ffmpeg on board)
tc_u02() {
    if [ -f "$ROOT/media_tools.sh" ]; then
        # shellcheck disable=SC1091
        . "$ROOT/media_tools.sh"
    fi
    if [ -z "$FFMPEG" ] && ! command -v ffmpeg >/dev/null 2>&1; then
        skip "TC-U02 record_clip (no ffmpeg — use PC RTSP record)"
        return 0
    fi
    tc_rtsp || { skip "TC-U02 needs rtsp_server"; return 0; }
    [ -x "$ROOT/record_clip.sh" ] || return 1
    sh "$ROOT/record_clip.sh" 5 cam0 >>"$LOG" 2>&1
    ls /mnt/data/clips/*.mp4 /mnt/sd/clips/*.mp4 2>/dev/null | head -1 | grep -q .
}

# Motion ioctl smoke (subset of TC-25)
tc_motion_smoke() {
    [ -x "$ROOT/test_debris" ] || return 1
    "$ROOT/test_debris" motion_ioctl >>"$LOG" 2>&1
}

# Vendor media snapshot
tc_vendor() {
    [ -x "$ROOT/check_vendor_media.sh" ] || return 0
    sh "$ROOT/check_vendor_media.sh" >>"$LOG" 2>&1
    return 0
}

run_case "TC-U01 motion_recorder dry-run" tc_u01 || true
run_case "TC-U03 health_check" tc_u03 || true
run_case "TC-U04 setup_dual_camera" tc_u04 || true
run_case "TC-U06 sync_probe" tc_u06 || true
run_case "RTSP edgeeye_cam / port 8554" tc_rtsp || true
run_case "TC-U02 record_clip" tc_u02 || true
run_case "TC-25 motion_ioctl (test_debris)" tc_motion_smoke || true
run_case "vendor media check" tc_vendor || true

log ""
log "===== verify_board summary: pass=$PASS fail=$FAIL skip=$SKIP ====="
log "log: $LOG"
log ""
log "PC-side (required for RTSP preview):"
log "  ffplay -rtsp_transport tcp rtsp://192.168.42.1:8554/cam0"
log "  ffmpeg -rtsp_transport tcp -i rtsp://192.168.42.1:8554/cam0 -c copy -t 10 clip.mp4"
log ""
log "Optional long-run: nohup ./stability_6h.sh 6 &"
log "Autostart test: ./install_autostart.sh && reboot"
log "Config: /root/edgeeye_cam.conf (mode/port/res)"

[ "$FAIL" -eq 0 ]
