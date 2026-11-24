#!/usr/bin/env bash
# One command to test the whole project. Used locally, by Claude, and by CI.
#
# Exit codes:
#   0  all tests passed
#   1  something failed (the real failing exit code is preserved where possible)
#   3  no tests are set up yet (not a pass!)
#
# Out of the box it auto-detects common stacks. Once your project settles,
# replace the auto-detection with the explicit commands you use. Keep it honest:
# never add "|| true" to hide failures.
set -u
cd "$(dirname "$0")/.."

ran=0
status=0

run() { # run <label> <command...>
  echo ""
  echo "==> $1"
  shift
  "$@"
  code=$?
  ran=$((ran + 1))
  if [ $code -ne 0 ]; then
    echo "FAILED (exit $code): $*"
    status=$code
  fi
  return 0
}

in_ci() { [ "${CI:-}" = "true" ]; }

# --- JavaScript / TypeScript -------------------------------------------------
if [ -f package.json ] && grep -q '"test"[[:space:]]*:' package.json \
   && ! grep -q 'no test specified' package.json; then
  if [ -f pnpm-lock.yaml ]; then pm=pnpm; elif [ -f yarn.lock ]; then pm=yarn; elif [ -f bun.lockb ] || [ -f bun.lock ]; then pm=bun; else pm=npm; fi
  if in_ci || [ ! -d node_modules ]; then
    if [ "$pm" = npm ] && [ -f package-lock.json ]; then run "install (npm ci)" npm ci
    else run "install ($pm)" "$pm" install; fi
  fi
  run "JS tests ($pm test)" "$pm" test
fi

# --- Python ------------------------------------------------------------------
if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f pytest.ini ] || [ -f setup.py ]; then
  py=python3; command -v python3 >/dev/null 2>&1 || py=python
  [ -x .venv/bin/python ] && py=.venv/bin/python
  if in_ci; then
    [ -f requirements.txt ] && run "install (requirements.txt)" "$py" -m pip install -q -r requirements.txt
    [ -f requirements-dev.txt ] && run "install (requirements-dev.txt)" "$py" -m pip install -q -r requirements-dev.txt
    [ -f pyproject.toml ] && [ ! -f requirements.txt ] && run "install (pyproject)" "$py" -m pip install -q -e ".[dev]"
    "$py" -m pytest --version >/dev/null 2>&1 || run "install pytest" "$py" -m pip install -q pytest
  fi
  echo ""
  echo "==> Python tests (pytest)"
  "$py" -m pytest -q
  code=$?
  ran=$((ran + 1))
  # pytest exit 5 = no tests collected: treat as "not set up", not as a pass.
  if [ $code -eq 5 ]; then ran=$((ran - 1)); echo "pytest found no tests."
  elif [ $code -ne 0 ]; then echo "FAILED (exit $code): pytest"; status=$code; fi
fi

# --- Go / Rust / .NET / Makefile ----------------------------------------------
[ -f go.mod ] && run "Go tests" go test ./...
[ -f Cargo.toml ] && run "Rust tests" cargo test
has_dotnet=0
for f in ./*.sln ./*.slnx ./*.csproj ./*/*.csproj ./*/*/*.csproj; do [ -f "$f" ] && has_dotnet=1; done
[ $has_dotnet -eq 1 ] && run ".NET tests" dotnet test
if [ $ran -eq 0 ] && [ -f Makefile ] && grep -qE '^test:' Makefile; then
  run "make test" make test
fi

# --- Result ------------------------------------------------------------------
echo ""
if [ $ran -eq 0 ]; then
  echo "NO TESTS SET UP YET (exit 3). This is not a pass."
  echo "Add at least one test, or edit scripts/test.sh to run your test command."
  exit 3
fi
if [ $status -ne 0 ]; then
  echo "RESULT: FAILED"
  exit $status
fi
echo "RESULT: PASSED ($ran suite(s))"
exit 0
