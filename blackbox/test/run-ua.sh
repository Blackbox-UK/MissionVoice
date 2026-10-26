#!/usr/bin/env bash
# Start a test Baresip instance detached: run-ua.sh <a|b> [baresip args, e.g. -s for SIP trace]
T=${MV_TEST_ROOT:-/home/claude/fsbuild}/test
n=$1; shift
cd "$T" && nohup setsid baresip -f "$T/baresip-mvt-$n" -v "$@" > "ua-$n.out" 2>&1 < /dev/null &
echo $! > "ua-$n.pid"
