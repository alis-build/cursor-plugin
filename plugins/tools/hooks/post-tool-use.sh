#!/usr/bin/env bash
# postToolUse hook (Cursor): everything this plugin says after a tool call,
# as one answer. Two hooks that each returned additional_context would
# overwrite one another (Cursor keeps the last), so both are gathered here:
#   - the secrets warning (warn-secrets.sh, which the alis binary answers);
#   - a Skill store match that suggest-skills.sh kept for this prompt, handed
#     over with the first tool result of the same generation.
# Fail-open: no output is Cursor's no-op.
hook_dir="$(cd "$(dirname "$0")" && pwd)"
payload="$(cat 2>/dev/null)" || exit 0
secrets="$(printf '%s' "$payload" | bash "$hook_dir/warn-secrets.sh" 2>/dev/null || true)"
# Without jq the secrets warning still goes out as the binary wrote it.
command -v jq >/dev/null 2>&1 || { [ -z "$secrets" ] || printf '%s\n' "$secrets"; exit 0; }

note=""
conversation="$(printf '%s' "$payload" | jq -r '
  (.conversation_id // "") | select(type == "string" and test("^[A-Za-z0-9_-]{1,128}$"))' 2>/dev/null || true)"
pending="${XDG_CACHE_HOME:-$HOME/.cache}/alis/cursor/$conversation.note"
if [ -n "$conversation" ] && [ -r "$pending" ]; then
  generation="$(printf '%s' "$payload" | jq -r '(.generation_id // "") | select(type == "string")' 2>/dev/null || true)"
  # Only the prompt the note was made for may receive it.
  note="$(jq -r --arg generation "$generation" 'select(.generation == $generation) | .note // empty' "$pending" 2>/dev/null || true)"
  rm -f "$pending" 2>/dev/null || true
fi
if [ -n "$note" ]; then
  note="About the request you are working on: $note
If the skill fits, load it before going further, or name it in your answer. If it does not fit, do not mention it."
fi

warning="$(printf '%s' "$secrets" | jq -r '.additional_context // empty' 2>/dev/null || true)"
if [ -z "$note" ]; then
  [ -z "$secrets" ] || printf '%s\n' "$secrets"
  exit 0
fi
jq -nc --arg warning "$warning" --arg note "$note" \
  '{additional_context: ([$warning, $note] | map(select(length > 0)) | join("\n\n"))}'
