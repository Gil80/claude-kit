#!/usr/bin/env bash
# Stop hook: Claude can't finish a turn while the tests it touched are failing.
# - Runs only when files changed since the last passing run (keeps chat turns fast).
# - Blocks once on failure (exit 2 sends the output back to Claude to fix).
# - Never loops: on a second consecutive block it warns you instead.
# Skip for one session with: export PROJECT_KIT_SKIP_TEST_GATE=1
set -u

input="$(cat 2>/dev/null || true)"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$dir" || exit 0

[ "${PROJECT_KIT_SKIP_TEST_GATE:-}" = "1" ] && exit 0
[ -f scripts/test.sh ] || exit 0

# Fingerprint the working tree so unchanged turns skip the test run.
fingerprint=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fingerprint="$( {
    git rev-parse HEAD 2>/dev/null
    git status --porcelain 2>/dev/null
    git diff 2>/dev/null
    git ls-files -o --exclude-standard -z 2>/dev/null | xargs -0 cksum 2>/dev/null
  } | cksum | tr -d ' ')"
  stamp=".claude/.test-gate-pass"
  if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$fingerprint" ]; then
    exit 0
  fi
fi

output="$(bash scripts/test.sh 2>&1)"
code=$?

if [ $code -eq 0 ]; then
  [ -n "$fingerprint" ] && printf '%s' "$fingerprint" > .claude/.test-gate-pass
  exit 0
fi

if [ $code -eq 3 ]; then
  # No tests yet: remind, don't block.
  printf '{"systemMessage":"project-kit: no tests are set up yet, so this work is unverified. Ask Claude to add a first test."}\n'
  exit 0
fi

failstamp=".claude/.test-gate-fail"
already_reported=0
[ -n "$fingerprint" ] && [ -f "$failstamp" ] && [ "$(cat "$failstamp")" = "$fingerprint" ] && already_reported=1
[ -n "$fingerprint" ] && printf '%s' "$fingerprint" > "$failstamp"

if [ $already_reported -eq 1 ] || printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  # Already blocked once this turn: don't loop. Tell the user instead.
  printf '{"systemMessage":"project-kit: tests are STILL failing (exit %s). Treat this work as not done."}\n' "$code"
  exit 0
fi

{
  echo "Tests are failing (scripts/test.sh exit $code). You may not finish yet."
  echo "Fix the failures, or if you can't, tell the user clearly that the work is NOT verified and why."
  echo "--- last 60 lines of output ---"
  printf '%s\n' "$output" | tail -n 60
} >&2
exit 2
