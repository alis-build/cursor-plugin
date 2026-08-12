#!/usr/bin/env bash
# sessionStart hook: refresh catalog metadata only. --cache-only is explicit
# for compatibility with older alis CLIs whose default sync installed native
# harness skills. Detached and fail-open; `{}` is Cursor's no-op hook output.
cat >/dev/null 2>&1 || true
if command -v alis >/dev/null 2>&1; then
  (alis skills sync --cache-only >/dev/null 2>&1 &)
fi
printf '{}\n'
exit 0
