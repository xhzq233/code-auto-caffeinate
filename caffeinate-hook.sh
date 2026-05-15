#!/usr/bin/env bash
# caffeinate-hook.sh
# Auto-prevent macOS sleep during Claude Code / Codex CLI sessions.
# Idempotent: only starts one caffeinate process per parent session.
# Uses caffeinate -w $PPID so it auto-exits when the parent process dies.

# Already watching this parent? Skip.
if pgrep -f "caffeinate.*-w ${PPID}" > /dev/null 2>&1; then
    exit 0
fi

# -d  prevent display sleep
# -i  prevent system idle sleep
# -m  prevent disk idle sleep
# -s  prevent system sleep (AC power only)
# -u  declare user active (keeps display on, prevents idle sleep)
# -w  exit when PID exits
caffeinate -dimsu -w "${PPID}" &
