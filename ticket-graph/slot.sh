#!/usr/bin/env bash
# Runs one heavy command (a test suite, a typecheck, a build) inside one of N machine-wide slots.
# Parallel ticket sessions share about 8 GB of RAM and a small /tmp, so at most N of them run
# heavy work at once. The lock is a file descriptor, so it's released even if the command dies.
# It uses the fixed fd 9, not `exec {fd}>`, because macOS ships bash 3.2.
# Usage: ~/.claude/skills/ticket-graph/slot.sh <command> [args...]   (N: TICKET_GRAPH_SLOTS, default 3)
# The api typecheck alone needs about 3 GB, so set TICKET_GRAPH_SLOTS=1 on a small machine.
set -u
n=${TICKET_GRAPH_SLOTS:-3}
dir="$HOME/.cache/ticket-graph"
mkdir -p "$dir"
waited=0
while :; do
  for i in $(seq 1 "$n"); do
    exec 9>"$dir/slot-$i.lock"
    if flock -n 9; then
      [ "$waited" -gt 0 ] && echo "slot.sh: got slot $i after ${waited}s" >&2
      "$@"
      status=$?
      exec 9>&-
      exit "$status"
    fi
    exec 9>&-
  done
  [ "$waited" -eq 0 ] && echo "slot.sh: all $n slots busy, waiting…" >&2
  sleep 5
  waited=$((waited + 5))
done
