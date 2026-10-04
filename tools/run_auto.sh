#!/bin/bash
# 사용: tools/run_auto.sh SEC [godot user args...]   (헤드리스 X, 스크린샷 가능)
cd "$(dirname "$0")/.."
SEC=$1; shift
perl -e 'alarm shift; exec @ARGV' "$SEC" /Applications/Godot.app/Contents/MacOS/Godot ${HEADLESS:+--headless} --path . -- --autoplay "$@" 2>&1
