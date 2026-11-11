#!/usr/bin/env bash
# The Skill store note on Cursor: asked for at beforeSubmitPrompt, handed over
# with the first tool result of the same generation.
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
mkdir -p "$home/bin"
# The fake CLI answers `skills suggest` with $ALIS_TEST_ANSWER and `hooks run`
# (the secrets handler) with $ALIS_TEST_SECRETS, and logs each call.
cat > "$home/bin/alis" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >> "$ALIS_TEST_LOG"
case "$1" in
  skills) cat > "$ALIS_TEST_REQUEST"; [ -z "${ALIS_TEST_ANSWER:-}" ] || printf '%s\n' "$ALIS_TEST_ANSWER" ;;
  hooks) cat > /dev/null; [ -z "${ALIS_TEST_SECRETS:-}" ] || printf '%s\n' "$ALIS_TEST_SECRETS" ;;
esac
exit 0
FAKE
chmod +x "$home/bin/alis"
export HOME="$home" PATH="$home/bin:$PATH" ALIS_TEST_LOG="$home/calls" ALIS_TEST_REQUEST="$home/request"
unset XDG_CACHE_HOME ALIS_SUGGEST_ALWAYS

ranked='Skill store match for this request — Alis skill: dbd-add-tracing-grpc-go — Adds tracing.
Load with `alis skills load dbd-add-tracing-grpc-go --via hook_hint` if relevant; otherwise ignore this note.'
guessed='Possibly relevant Alis skill: build-your-first-ios-app — Guide builders.'
wake='The user addressed alis by name. Before doing anything else: …'

submit() { # $1 = conversation, $2 = generation, $3 = prompt, $4 = the CLI's answer
  jq -nc --arg c "$1" --arg g "$2" --arg p "$3" \
    '{hook_event_name:"beforeSubmitPrompt", conversation_id:$c, generation_id:$g, prompt:$p, workspace_roots:["/work/site"]}' \
    | ALIS_TEST_ANSWER="${4:-}" bash "$dir/suggest-skills.sh"
}
tool() { # $1 = conversation, $2 = generation
  jq -nc --arg c "$1" --arg g "$2" \
    '{hook_event_name:"postToolUse", conversation_id:$c, generation_id:$g, tool_name:"Shell", tool_input:{command:"ls"}, tool_output:"ok"}' \
    | bash "$dir/post-tool-use.sh"
}
fail() { echo "$1" >&2; exit 1; }
calls() { if [ -f "$home/calls" ]; then grep -c '^skills suggest' "$home/calls" || true; else echo 0; fi; }

# 1. The prompt goes to the CLI in the shape it reads, and the prompt is never held up.
out="$(submit c1 g1 'add tracing to my grpc service' "$ranked")"
[ "$out" = '{"continue":true}' ] || fail "beforeSubmitPrompt answered: $out"
grep -q '^skills suggest --hook --harness codex$' "$home/calls" || fail "unexpected CLI call: $(cat "$home/calls")"
jq -e '. == {hook_event_name:"UserPromptSubmit", session_id:"c1", cwd:"/work/site", permission_mode:"", prompt:"add tracing to my grpc service"}' \
  "$home/request" >/dev/null || fail "unexpected request: $(cat "$home/request")"

# 2. The first tool result of that generation carries the note, once.
out="$(tool c1 g1 | jq -r '.additional_context')"
case "$out" in "About the request you are working on: Skill store match"*"dbd-add-tracing-grpc-go"*"If it does not fit, do not mention it.") ;;
  *) fail "the note was not handed over: $out" ;; esac
[ -z "$(tool c1 g1)" ] || fail 'the note was handed over twice'

# 3. A note no tool call collected does not reach a later prompt.
submit c2 g1 'add tracing to my grpc service' "$ranked" >/dev/null
[ -z "$(tool c2 g2)" ] || fail 'a stale note reached another generation'
[ -z "$(tool c2 g1)" ] || fail 'a note survived being found stale'
submit c3 g1 'add tracing to my grpc service' "$ranked" >/dev/null
submit c3 g2 'rename this variable everywhere' '' >/dev/null
[ -z "$(tool c3 g2)" ] || fail 'the next prompt inherited the earlier note'

# 4. A local guess and a wake-phrase instruction are not kept.
submit c4 g1 'how are sendgrid templates managed' "$guessed" >/dev/null
[ -z "$(tool c4 g1)" ] || fail 'a local guess was handed over'
submit c4 g2 'alis, find me a tracing skill' "$wake" >/dev/null
[ -z "$(tool c4 g2)" ] || fail 'a wake instruction was handed over'

# 5. A secrets warning and a note go out together; a warning alone is untouched.
submit c5 g1 'add tracing to my grpc service' "$ranked" >/dev/null
out="$(ALIS_TEST_SECRETS='{"additional_context":"A stripe key was printed; ask for it to be rotated."}' tool c5 g1 | jq -r '.additional_context')"
case "$out" in "A stripe key was printed"*"About the request you are working on: Skill store match"*) ;; *) fail "warning and note were not combined: $out" ;; esac
out="$(ALIS_TEST_SECRETS='{"additional_context":"A stripe key was printed."}' tool c5 g9)"
[ "$out" = '{"additional_context":"A stripe key was printed."}' ] || fail "a warning alone was changed: $out"

# 6. Switched off, with an unusable conversation id, or with no prompt, the CLI is not asked.
before="$(calls)"
[ "$(ALIS_SUGGEST_ALWAYS=0 submit c6 g1 'add tracing to my grpc service' "$ranked")" = '{"continue":true}' ] || fail 'switched off, the prompt was held up'
[ "$(submit '../x' g1 'add tracing to my grpc service' "$ranked")" = '{"continue":true}' ] || fail 'a bad conversation id held the prompt up'
[ "$(submit c6 g1 '' "$ranked")" = '{"continue":true}' ] || fail 'an empty prompt was held up'
[ "$(calls)" = "$before" ] || fail 'the CLI was asked when it should not have been'
[ "$(printf 'not json' | bash "$dir/suggest-skills.sh")" = '{"continue":true}' ] || fail 'a bad payload held the prompt up'

# 7. Without the alis CLI both hooks stay out of the way.
[ "$(PATH=/usr/bin:/bin bash "$dir/suggest-skills.sh" <<<'{"conversation_id":"c7","prompt":"add tracing"}')" = '{"continue":true}' ] || fail 'a missing CLI held the prompt up'
[ -z "$(PATH=/usr/bin:/bin bash "$dir/post-tool-use.sh" <<<'{"conversation_id":"c7","generation_id":"g1"}')" ] || fail 'a missing CLI produced output'

# 8. Both hooks are registered.
jq -e 'any(.hooks.beforeSubmitPrompt[]; .command == "./suggest-skills.sh")' "$dir/hooks.json" >/dev/null || fail 'suggest-skills.sh must run on beforeSubmitPrompt'

echo 'skill note: asked at submit, handed over with the first tool result of the same prompt, never stale, never blocking'
