#!/usr/bin/env bash
# postToolUse hook (Cursor): warn when a tool call carried secret-looking
# values; never redacts. secrets-hook.py is the Claude plugin's scanner, copied
# verbatim; this script only maps Cursor's payload onto the classic hook shape
# it reads (tool_output is the tool's JSON-stringified result, whose string
# leaves are the text the transcript holds) and its answer back onto Cursor's
# one channel, additional_context. Python only starts when the payload holds a
# trigger of some pattern (or an alis environment command, whose revealed rows
# have no trigger of their own).
set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
payload=$(cat 2>/dev/null) || exit 0
printf '%s' "$payload" | grep -qiE 'sk_(live|test)_|gh[oprsu]_|github_pat_|npm_|pypi-|lin_api_|SG\.|://|AKIA|AIza|xox[abpr]-|PRIVATE KEY|SECRET|TOKEN|PASSW|API_?KEY|alis (--\S+ )*(environment|environments|envs?) ' || exit 0
classic=$(printf '%s' "$payload" | jq -c '
  ((.tool_output // "") | if type == "string" then (try fromjson catch .) else . end) as $out
  | {
      session_id: (.conversation_id // .session_id // null),
      hook_event_name: "PostToolUse",
      tool_name: (.tool_name // "tool"),
      tool_input: (.tool_input // {}),
      tool_response: { stdout: ([$out | .. | strings] | join("\n")), stderr: "" }
    }' 2>/dev/null) || exit 0
printf '%s' "$classic" | python3 -B "$(dirname "$0")/secrets-hook.py" \
  | jq -c '{additional_context: .hookSpecificOutput.additionalContext} | select(.additional_context != null)' 2>/dev/null || true
exit 0
