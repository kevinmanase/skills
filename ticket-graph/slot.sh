#!/usr/bin/env bash
# Runs one heavy command (a test suite, a typecheck, a build) inside one of N machine-wide slots.
# Parallel ticket sessions share about 8 GB of RAM and a small /tmp, so at most N of them run
# heavy work at once. The lock is a file descriptor, so it's released even if the command dies.
# Usage: ~/.claude/skills/ticket-graph/slot.sh <command> [args...]   (N: TICKET_GRAPH_SLOTS, default 1)
# The default is 1 because finished chats now stay open (about 0.4 GB each) and the api typecheck
# alone needs about 3 GB, so two heavy runs at once swap the box and get killed. Raise it when memory allows.
set -u
n=${TICKET_GRAPH_SLOTS:-1}
dir="$HOME/.cache/ticket-graph"
mkdir -p "$dir"
waited=0
while :; do
  for i in $(seq 1 "$n"); do
    exec {fd}>"$dir/slot-$i.lock"
    if flock -n "$fd"; then
      [ "$waited" -gt 0 ] && echo "slot.sh: got slot $i after ${waited}s" >&2
      "$@"
      status=$?
      exec {fd}>&-
      exit "$status"
    fi
    exec {fd}>&-
  done
  [ "$waited" -eq 0 ] && echo "slot.sh: all $n slots busy, waiting…" >&2
  sleep 5
  waited=$((waited + 5))
done
