#!/usr/bin/env bash
# The postToolUse secrets warning on Cursor's payload: tool_output is the
# tool's JSON-stringified result, and the only channel back is
# additional_context. Every value here is a made-up shape, never a real
# credential; the Stripe one is assembled so no scanner reads the source as a key.
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
hook="$dir/warn-secrets.sh"
test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT

stripe="sk_live_$(printf 'FAKE%.0s' 1 2 3 4 5)0000"
linear="lin_api_FAKEFAKEFAKEFAKEFAKE0000"

run_hook() { # $1 = conversation, $2 = command, $3 = output text (wrapped as the shell tool's JSON result)
  jq -nc --arg s "$1" --arg c "$2" --arg o "$3" \
    '{conversation_id:$s, hook_event_name:"postToolUse", tool_name:"Shell", tool_use_id:"t1", tool_input:{command:$c}, tool_output:({output:$o, exit_code:0} | tojson)}' \
    | HOME="$test_home" bash "$hook"
}
context() { run_hook "$@" | jq -r '.additional_context // empty'; }

# A leaked key tells the agent which kinds landed and to ask for rotation, never the value.
out="$(context s1 'cat .env' "$stripe")"
case "$out" in *stripe*rotate*) ;; *) echo "unexpected context: $out" >&2; exit 1 ;; esac
case "$out" in *"$stripe"*) echo 'the warning carried the value' >&2; exit 1 ;; esac
run_hook s1 'cat .env' "$linear" | jq -e 'keys == ["additional_context"]' >/dev/null

# The same value in the same conversation warns once; a new value still warns.
[ -z "$(run_hook s1 'cat .env' "$stripe")" ] || { echo 'a value already warned about warned again' >&2; exit 1; }

# Rows an alis environment reveal printed count as revealed, for that command only.
revealed='{"environments":[{"environmentId":"production","envs":[{"name":"DB_PASSWORD","value":"FAKE-long-value-abcdefghij"}]}],"revealed":true}'
case "$(context s2 'alis environment variables alis.os --reveal --json' "$revealed")" in *revealed*) ;; *) echo 'reveal output was not reported' >&2; exit 1 ;; esac
[ -z "$(run_hook s2 'cat out.json' "$revealed")" ] || { echo 'name/value JSON from another command was reported' >&2; exit 1; }

# The masked default output is silent, as is clean output.
[ -z "$(run_hook s3 'alis environment variables alis.os' 'DB_PASSWORD   ••••••••')" ] || { echo 'masked output was reported' >&2; exit 1; }
[ -z "$(run_hook s3 'echo ok' 'ok')" ]

# A written file is scanned through its arguments; a tool_output that is not JSON is scanned as text.
jq -nc --arg g "ghp_FAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE0000" '{conversation_id:"s4", tool_name:"Write", tool_input:{path:"/x/.env", contents:$g}, tool_output:"ok"}' \
  | HOME="$test_home" bash "$hook" | jq -e '.additional_context | contains("github")' >/dev/null
jq -nc --arg n "npm_FAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE0000" '{conversation_id:"s4", tool_name:"Shell", tool_input:{command:"cat x"}, tool_output:$n}' \
  | HOME="$test_home" bash "$hook" | jq -e '.additional_context | contains("npm")' >/dev/null

# No output and a non-JSON payload are silent.
[ -z "$(printf '{"conversation_id":"s5","tool_name":"Shell"}' | HOME="$test_home" bash "$hook")" ]
[ -z "$(printf 'not json' | HOME="$test_home" bash "$hook")" ]

# The hook is registered on postToolUse.
jq -e 'any(.hooks.postToolUse[]; .command == "./warn-secrets.sh")' "$dir/hooks.json" >/dev/null || {
  echo 'warn-secrets.sh must run on postToolUse' >&2; exit 1; }
echo 'warn-secrets behavior: OK'
