#!/usr/bin/env bash
set -euo pipefail
#
# code-auto-caffeinate — auto-prevent macOS sleep during Claude Code / Codex sessions.
#
# Install:   curl -sL https://raw.githubusercontent.com/xhzq233/code-auto-caffeinate/main/bootstrap.sh | bash
# Uninstall: curl -sL https://raw.githubusercontent.com/xhzq233/code-auto-caffeinate/main/bootstrap.sh | bash -s -- -u
#

INSTALL_DIR="${HOME}/.code-auto-caffeinate"
HOOK_SCRIPT="${INSTALL_DIR}/caffeinate-hook.sh"

# ── Parse args ───────────────────────────────────────────────────────
ACTION="install"
for a in "$@"; do
    case "$a" in -u|--uninstall) ACTION="uninstall" ;; esac
done

# ── macOS check ──────────────────────────────────────────────────────
if [ "$(uname)" != "Darwin" ]; then
    echo "Error: caffeinate is macOS-only" >&2; exit 1
fi

# ── Embedded hook script ────────────────────────────────────────────
write_hook_script() {
    mkdir -p "${INSTALL_DIR}"
    cat > "${HOOK_SCRIPT}" << 'HOOK'
#!/usr/bin/env bash
# caffeinate-hook.sh — idempotent, one instance per parent session.
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
HOOK
    chmod +x "${HOOK_SCRIPT}"
}

# ── JSON helper: add/remove SessionStart hook ────────────────────────
json_session_start() {
    # Usage: json_session_start <file> <add|remove>
    local target="$1" op="$2"
    python3 -c '
import json, os, sys

target, op = sys.argv[1], sys.argv[2]
hook_script = os.environ["HOOK_SCRIPT"] if "HOOK_SCRIPT" in os.environ else ""

if os.path.exists(target):
    with open(target) as f:
        data = json.load(f)
else:
    data = {}

hooks = data.setdefault("hooks", {})
ss = hooks.setdefault("SessionStart", [])

def has_our_hook(g):
    return any("caffeinate-hook.sh" in h.get("command", "") for h in g.get("hooks", []))

if op == "add":
    for g in ss:
        if has_our_hook(g):
            print("  Already installed, skipping.")
            sys.exit(0)
    ss.append({"hooks": [{"type": "command", "command": hook_script}]})
elif op == "remove":
    before = len(ss)
    ss[:] = [g for g in ss if not has_our_hook(g)]
    if not ss and "SessionStart" in hooks:
        del hooks["SessionStart"]
    if not hooks:
        del data["hooks"]

if not data:
    os.remove(target)
    print(f"  Removed empty {target}")
else:
    with open(target, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    if op == "add":
        print(f"  Written to {target}")
    else:
        removed = before - len(ss) if "before" in dir() else 0
        print(f"  Removed hook from {target}" if removed else "  No caffeinate hook found.")
' "$target" "$op"
}

# ── Install ──────────────────────────────────────────────────────────
do_install() {
    write_hook_script
    export HOOK_SCRIPT

    echo "[1/2] Claude Code"
    json_session_start "${HOME}/.claude/settings.json" add

    echo ""
    echo "[2/2] Codex CLI"
    # Enable hooks feature flag (use [features].hooks, NOT deprecated codex_hooks)
    local cfg="${HOME}/.codex/config.toml"
    mkdir -p "$(dirname "$cfg")"
    if [ -f "$cfg" ]; then
        if grep -q "^hooks *=" "$cfg"; then
            : # already set
        elif grep -q '^\[features\]' "$cfg"; then
            sed -i '' '/^\[features\]/a\
hooks = true
' "$cfg"
        else
            printf '\n[features]\nhooks = true\n' >> "$cfg"
        fi
    else
        printf '[features]\nhooks = true\n' > "$cfg"
    fi
    echo "  Written to ${cfg}"
    json_session_start "${HOME}/.codex/hooks.json" add

    echo ""
    echo "Done. caffeinate -dimsu will start automatically when you open"
    echo "Claude Code or Codex, and stop when the session ends."
}

# ── Uninstall ────────────────────────────────────────────────────────
do_uninstall() {
    export HOOK_SCRIPT

    echo "[1/2] Claude Code"
    json_session_start "${HOME}/.claude/settings.json" remove

    echo ""
    echo "[2/2] Codex CLI"
    json_session_start "${HOME}/.codex/hooks.json" remove

    rm -rf "${INSTALL_DIR}"
    echo "  Removed ${INSTALL_DIR}"

    # Kill any stray caffeinate processes from our hook
    pkill -f "caffeinate.*-dimsu" 2>/dev/null || true

    echo ""
    echo "Done. Uninstalled code-auto-caffeinate."
}

# ── Main ─────────────────────────────────────────────────────────────
case "${ACTION}" in
    install)   do_install   ;;
    uninstall) do_uninstall ;;
esac
