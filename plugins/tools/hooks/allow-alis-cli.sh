#!/usr/bin/env bash
# beforeShellExecution hook (Cursor): auto-approve `alis` CLI invocations so the
# agent can run the Alis Build command-line tool without a permission prompt on
# every call.
#
# Why this exists: Cursor prompts for shell commands (subject to the user's
# auto-run settings), and a plugin cannot ship user/project allowlist entries.
# A beforeShellExecution hook is the plugin-native equivalent: it inspects the
# pending command and returns {"permission": "allow"} for clean `alis ...`
# invocations, so the rule travels with the plugin to everyone who installs it.
#
# Safety: we ONLY auto-approve a single, simple `alis <subcommand> ...` command.
# If the command chains or redirects (|, &&, ||, ;, &, >, <, backtick, $(...),
# newline) we emit NOTHING and exit 0, deferring to Cursor's normal permission
# flow. This prevents `alis define && rm -rf /`-style smuggling from riding on
# the allow. Explicit-approval flags (--confirm-production, --approve) and
# `blocks uninstall --yes` return {"permission": "ask"} so the human always
# sees a prompt for those, even with auto-run enabled — deliberate double-keying.
#
# Scope: by default every `alis` subcommand is auto-approved. To restrict, set
# ALIS_ALLOWED_SUBCMDS to a space-separated allowlist (e.g. "define build
# deploy operations"); any other subcommand then falls through to a prompt.
#
# Reads the hook payload (JSON) on stdin and writes the hook response to stdout.
set -euo pipefail

# Without jq we cannot parse the payload; emit nothing and exit 0 so the call
# proceeds through Cursor's normal permission flow (graceful degradation).
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.command // empty' 2>/dev/null || true)"
[ -n "$cmd" ] || exit 0

# Reject anything that splits into multiple shell segments or redirects. We keep
# this conservative: a legitimately-quoted metacharacter just means the user
# gets a normal prompt this once, which is safe degradation.
case "$cmd" in
  *'|'* | *'&'* | *';'* | *'<'* | *'>'* | *'`'* | *'$('* | *$'\n'*)
    exit 0
    ;;
esac

# First token must be exactly `alis`; capture the subcommand (second token).
read -r first sub _rest <<EOF
$cmd
EOF
[ "$first" = "alis" ] || exit 0

# Record the harness state for the alis CLI's approval gate. Cursor exposes no
# permission-mode signal, so this record is audit/forward-compatibility only —
# the CLI does not treat it as a standing grant (permission_mode "default").
# Best-effort — every failure path falls through so the decision below is never
# affected. Written before the double-key carve-outs so the record exists even
# when this hook asks for a prompt.
sid="$(printf '%s' "$payload" | jq -r '.conversation_id // .session_id // empty' 2>/dev/null || true)"
if mkdir -p "$HOME/.alis" 2>/dev/null && tmp="$(mktemp "$HOME/.alis/.agent-approval.XXXXXX" 2>/dev/null)"; then
  if jq -nc --arg s "$sid" --arg c "$cmd" \
      '{version: 1, harness: "cursor", permission_mode: "default", session_id: $s, command: $c, written_at: (now | todate)}' \
      >"$tmp" 2>/dev/null; then
    chmod 600 "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$HOME/.alis/agent-approval.json" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
fi

ask() {
  jq -nc --arg m "$1" '{permission: "ask", user_message: $m, agent_message: $m}'
  exit 0
}

# Never auto-approve explicit-approval flags: --confirm-production (production
# deploy gate), --approve (the CLI's human pre-approval flag), and
# `blocks uninstall --yes` (destructive, prompt-skipping). Returning "ask" means
# the human sees Cursor's permission prompt in addition to having approved in
# chat — deliberate double-keying.
case "$cmd" in
  *'--confirm-production'* | *'--approve'*)
    ask "Explicit-approval flag requires the human to confirm this command (Alis Build plugin)."
    ;;
esac
if [ "$sub" = "blocks" ] || [ "$sub" = "block" ]; then
  case "$cmd" in
    *uninstall*--yes* | *--yes*uninstall*)
      ask "Destructive uninstall requires the human to confirm this command (Alis Build plugin)."
      ;;
  esac
fi

# Optional allowlist of subcommands.
if [ -n "${ALIS_ALLOWED_SUBCMDS:-}" ]; then
  allowed=0
  for s in $ALIS_ALLOWED_SUBCMDS; do
    [ "$s" = "$sub" ] && { allowed=1; break; }
  done
  [ "$allowed" -eq 1 ] || exit 0
fi

# Approve the call. agent_message is surfaced to the agent for audit.
jq -nc '{
  permission: "allow",
  agent_message: "Auto-approved alis CLI command (Alis Build plugin)"
}'
