#!/bin/sh
# run_edgeeye_cam.sh — 兼容入口，转 run_edgeeye_stack.sh
exec sh "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/run_edgeeye_stack.sh" "$@"
