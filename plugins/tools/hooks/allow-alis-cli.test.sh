#!/usr/bin/env bash
# The beforeShellExecution gate: clean alis commands are allowed, explicit
# approval flags and the commands that print or write environment secret
# values ask, and anything chained or redirected is left to Cursor.
set -euo pipefail
hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT

decide() { # $1 = command
  jq -nc --arg c "$1" '{conversation_id:"conv-1", command:$c, cwd:"/tmp"}' | HOME="$test_home" bash "$hook_dir/allow-alis-cli.sh"
}
assert_allow() {
  decide "$1" | jq -e '.permission == "allow"' >/dev/null || { echo "expected allow: $1" >&2; exit 1; }
}
assert_ask() { # $1 = command, $2 = word the messages must carry
  local out; out="$(decide "$1")"
  printf '%s' "$out" | jq -e --arg w "$2" '.permission == "ask" and (.user_message | contains($w)) and (.agent_message | contains($w))' >/dev/null \
    || { echo "expected ask mentioning '$2': $1 -> $out" >&2; exit 1; }
}
assert_silent() {
  [ -z "$(decide "$1")" ] || { echo "expected no decision: $1" >&2; exit 1; }
}

assert_allow 'alis build alis.os.console.v2 --json'
assert_allow 'alis environment list alis.os --json'
assert_allow 'alis env set dev KEY=1 --json'
assert_allow 'alis environment new alis.os --region europe-west1 --json'
assert_allow 'alis ask reveal variables'

assert_ask 'alis deploy alis.os.console.v2 --confirm-production --json' 'Explicit-approval'
assert_ask 'alis blocks uninstall blocks/example --yes' 'Destructive'

# Commands that print or write environment secret values (ticket 4531a10b):
# variables|vars print every value on CLIs before 1.146.1 and behind --reveal
# since, refresh writes or prints the .env; a flag ahead of the verb must not
# slip past, and --reveal asks wherever it appears.
assert_ask 'alis environment variables alis.os' 'secret'
assert_ask 'alis env vars alis.os --json' 'secret'
assert_ask 'alis envs variables alis.os --reveal -e production' 'secret'
assert_ask 'alis environments refresh alis.os --output .env' 'secret'
assert_ask 'alis environment --json variables alis.os' 'secret'
assert_ask 'alis --json env refresh alis.os' 'secret'
assert_ask 'alis whoami --reveal' 'secret'

assert_silent 'alis build --json && echo unsafe'
assert_silent 'alis environment variables alis.os | tee out'
assert_silent 'echo alis environment variables'
[ -z "$(printf 'not json' | HOME="$test_home" bash "$hook_dir/allow-alis-cli.sh")" ]

# The approval record is written for the gated commands too (audit only on Cursor).
decide 'alis environment variables alis.os' >/dev/null
jq -e '.harness == "cursor" and .permission_mode == "default" and .session_id == "conv-1"' "$test_home/.alis/agent-approval.json" >/dev/null

echo 'allow-alis-cli behavior: OK'
