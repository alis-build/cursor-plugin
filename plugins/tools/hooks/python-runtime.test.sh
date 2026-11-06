#!/usr/bin/env bash
set -eu
repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
exec python3 -B "$repo_root/tests/test_python_runtime.py"
