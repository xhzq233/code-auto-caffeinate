#!/usr/bin/env bash
# caffeinate-hook.sh
# Idempotent: only starts one caffeinate process per parent session.
# Uses nohup + double-fork to fully detach from the hook runner.

# Already watching this parent? Skip.
if pgrep -f "caffeinate.*-w ${PPID}" > /dev/null 2>&1; then
    exit 0
fi

# Fully detach so the hook runner is not blocked.
# -d  prevent display sleep
# -i  prevent system idle sleep
# -m  prevent disk idle sleep
# -s  prevent system sleep (AC power only)
# -u  declare user active (keeps display on, prevents idle sleep)
# -w  exit when PID exits
(caffeinate -dimsu -w "${PPID}" </dev/null >/dev/null 2>&1 &)
