# code-auto-caffeinate

Auto-prevent macOS sleep during Claude Code & Codex CLI sessions.

Both tools have built-in sleep prevention, but they're weak — Claude Code only uses `caffeinate -i`, Codex doesn't prevent lid-close sleep. This hook runs `caffeinate -dimsu -w $PPID` for full protection.

## Install

```bash
curl -sL https://raw.githubusercontent.com/xhzq233/code-auto-caffeinate/main/bootstrap.sh | bash
```

## Uninstall

```bash
curl -sL https://raw.githubusercontent.com/xhzq233/code-auto-caffeinate/main/bootstrap.sh | bash -s -- -u
```

## How it works

- Adds a `SessionStart` hook to both `~/.claude/settings.json` and `~/.codex/hooks.json`
- On session start: runs `caffeinate -dimsu -w $PPID` in the background
- Caffeinate watches the parent process PID — when Claude Code / Codex exits, caffeinate stops automatically
- Idempotent: running it multiple times only creates one caffeinate instance per session

### caffeinate flags

| Flag | Effect |
|------|--------|
| `-d` | Prevent display sleep |
| `-i` | Prevent system idle sleep |
| `-m` | Prevent disk idle sleep |
| `-s` | Prevent system sleep (AC power only) |
| `-u` | Declare user active (keeps display on) |
| `-w $PPID` | Auto-exit when parent process dies |
