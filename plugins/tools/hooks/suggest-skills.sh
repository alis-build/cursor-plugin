#!/usr/bin/env bash
# beforeSubmitPrompt hook (Cursor): ask the Skill store which skill fits the
# prompt, and keep the answer for deliver-skill-note.sh.
#
# Cursor's beforeSubmitPrompt can allow or block a prompt but cannot add
# context for the model, so the note cannot go beside the prompt as it does in
# the other plugins. It is kept per conversation, stamped with this prompt's
# generation, and handed over with the first tool result of the same
# generation (postToolUse can add context). A prompt answered without a tool
# call gets no note.
#
# The alis CLI (1.187.18 or later) asks the Skill store once the prompt passes
# its gates and answers "Skill store match for this request …" or nothing. Its
# other answers are not kept: a "Possibly relevant Alis skill" guess from the
# local word matcher named unrelated skills too often, and a wake-phrase
# instruction would arrive too late to be one (the discover and capture rules
# cover those here). ALIS_SUGGEST_ALWAYS=0 switches this off.
#
# Always answers {"continue": true}: discovery must never hold up a prompt.
proceed() { printf '{"continue":true}\n'; exit 0; }
payload="$(cat 2>/dev/null)" || proceed
[ "${ALIS_SUGGEST_ALWAYS:-1}" != "0" ] || proceed
command -v jq >/dev/null 2>&1 || proceed
command -v alis >/dev/null 2>&1 || proceed

request="$(printf '%s' "$payload" | jq -c '
  select((.prompt // "") | type == "string" and length > 0) |
  select((.conversation_id // "") | type == "string" and test("^[A-Za-z0-9_-]{1,128}$")) |
  {hook_event_name: "UserPromptSubmit", session_id: .conversation_id,
   cwd: ((.workspace_roots // []) | if type == "array" then (map(select(type == "string"))[0] // "") else "" end),
   permission_mode: "", prompt: .prompt}' 2>/dev/null)" || proceed
[ -n "$request" ] || proceed
conversation="$(printf '%s' "$request" | jq -r '.session_id' 2>/dev/null)" || proceed
generation="$(printf '%s' "$payload" | jq -r '(.generation_id // "") | select(type == "string")' 2>/dev/null)" || proceed

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/alis/cursor"
pending="$state_dir/$conversation.note"
# A note from an earlier prompt that no tool call collected is stale now.
rm -f "$pending" 2>/dev/null || true

# Swallow every CLI failure (an older alis that rejects --hook exits 1). The
# codex shape is plain text.
out="$(printf '%s' "$request" | alis skills suggest --hook --harness codex 2>/dev/null)" || proceed
case "$out" in
  "Skill store match"*) ;;
  *) proceed ;;
esac
if mkdir -p "$state_dir" 2>/dev/null; then
  jq -nc --arg generation "$generation" --arg note "$out" '{generation: $generation, note: $note}' \
    > "$pending" 2>/dev/null || rm -f "$pending" 2>/dev/null
fi
proceed
