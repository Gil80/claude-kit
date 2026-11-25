#!/usr/bin/env bash
# Tests for the project-kit plugin scripts. Run: bash tests/run.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
kit="$root/plugins/project-kit"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0

check() { # check <name> <expected-exit> <actual-exit> [haystack] [needle]
  local ok=1
  [ "$2" = "$3" ] || ok=0
  if [ $# -ge 5 ] && ! printf '%s' "$4" | grep -qF -- "$5"; then ok=0; fi
  if [ $ok -eq 1 ]; then pass=$((pass+1)); echo "ok   $1"
  else fail=$((fail+1)); echo "FAIL $1 (exit $3, wanted $2)"; [ $# -ge 5 ] && echo "     wanted text: $5" && printf '%s\n' "$4" | sed 's/^/     | /' | head -20; fi
}
check_absent() { # check_absent <name> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then fail=$((fail+1)); echo "FAIL $1 (found: $3)"; else pass=$((pass+1)); echo "ok   $1"; fi
}

guard() { printf '%s' "$1" | CLAUDE_PLUGIN_ROOT="$kit" bash "$kit/hooks/secret-guard.sh" 2>&1; }
start() { CLAUDE_PROJECT_DIR="$1" CLAUDE_PLUGIN_ROOT="$kit" bash "$kit/hooks/session-start.sh" </dev/null 2>&1; }

echo "== JSON files parse"
for f in "$root/.claude-plugin/marketplace.json" "$kit/.claude-plugin/plugin.json" "$kit/hooks/hooks.json" "$kit/template/.claude/settings.json"; do
  python3 -m json.tool "$f" >/dev/null 2>&1; check "valid json: ${f#$root/}" 0 $?
done

echo "== secret guard"
out=$(guard '{"tool_name":"Read","tool_input":{"file_path":"/p/.env"}}'); check "blocks Read .env" 2 $? "$out" "secret guard"
out=$(guard '{"tool_name":"Read","tool_input":{"file_path":"/p/.env.production"}}'); check "blocks Read .env.production" 2 $?
out=$(guard '{"tool_name":"Read","tool_input":{"file_path":"/p/.env.example"}}'); check "allows Read .env.example" 0 $?
out=$(guard '{"tool_name":"Read","tool_input":{"file_path":"/p/src/env.ts"}}'); check "allows Read env.ts" 0 $?
out=$(guard '{"tool_name":"Write","tool_input":{"file_path":"/p/certs/server.pem","content":"x"}}'); check "blocks Write .pem" 2 $?
out=$(guard '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}'); check "blocks cat .env" 2 $?
out=$(guard '{"tool_name":"Bash","tool_input":{"command":"grep KEY ./config/.env.local"}}'); check "blocks grep .env.local" 2 $?
out=$(guard '{"tool_name":"Bash","tool_input":{"command":"source .env && npm start"}}'); check "blocks source .env" 2 $?
out=$(guard '{"tool_name":"Bash","tool_input":{"command":"cat .env.example"}}'); check "allows cat .env.example" 0 $?
out=$(guard '{"tool_name":"Bash","tool_input":{"command":"cp .env.example .env"}}'); check "allows cp .env.example .env" 0 $?
out=$(guard '{"tool_name":"Bash","tool_input":{"command":"node -e \"console.log(process.env.HOME)\""}}'); check "allows process.env" 0 $?
out=$(guard '{"tool_name":"Bash","tool_input":{"command":"npm test"}}'); check "allows npm test" 0 $?

echo "== session start"
mkdir -p "$tmp/empty"; out=$(start "$tmp/empty"); check "empty folder offers bootstrap" 0 $? "$out" "EMPTY"
mkdir -p "$tmp/existing"; echo x > "$tmp/existing/app.py"; out=$(start "$tmp/existing"); check "existing project without .project-kit runs" 0 $?; [ -z "$out" ]; check "existing project without .project-kit stays silent" 0 $?
mkdir -p "$tmp/partial"; echo x > "$tmp/partial/app.py"; cp "$kit/template/.project-kit" "$tmp/partial/"; out=$(start "$tmp/partial"); check "bootstrapped project lists missing files" 0 $? "$out" "scripts/test.sh"
mkdir -p "$tmp/ignored"; echo x > "$tmp/ignored/a"; touch "$tmp/ignored/.project-kit-ignore"
out=$(start "$tmp/ignored"); check "opt-out file silences hook" 0 $?; [ -z "$out" ]; check "opt-out output empty" 0 $?
out=$(CLAUDE_PROJECT_DIR="$HOME" CLAUDE_PLUGIN_ROOT="$kit" bash "$kit/hooks/session-start.sh" </dev/null); [ -z "$out" ]; check "home folder stays quiet" 0 $?

echo "== copy template"
p="$tmp/proj"; mkdir -p "$p"; echo "# Mine" > "$p/README.md"
out=$(bash "$kit/scripts/copy-template.sh" "$p"); check "copy runs" 0 $? "$out" "SKIPPED  README.md"
grep -q "# Mine" "$p/README.md"; check "existing README untouched" 0 $?
[ -x "$p/scripts/test.sh" ] && [ -f "$p/.project-kit" ] && [ -f "$p/.claude/settings.json" ] && [ -f "$p/.gitignore" ] && [ -f "$p/.github/workflows/ci.yml" ]; check "standard files created" 0 $?
out=$(bash "$kit/scripts/copy-template.sh" "$p" --diff); check "diff mode" 0 $? "$out" "DIFFERS  README.md"
out=$(start "$p"); check "complete project gets maintenance note" 0 $? "$out" "checkup"
check_absent "complete project not told to bootstrap" "$out" "missing parts"
sed -i.bak "s/^last_checkup=.*/last_checkup=$(date +%s)/" "$p/.project-kit" && rm -f "$p/.project-kit.bak"
out=$(start "$p"); check_absent "fresh checkup + same version is quiet" "$out" "Maintenance"
sed -i.bak "s/^version=.*/version=0.9.0/" "$p/.project-kit" && rm -f "$p/.project-kit.bak"
out=$(start "$p"); check "old kit version suggests checkup" 0 $? "$out" "version 0.9.0"

echo "== test.sh"
out=$(cd "$p" && bash scripts/test.sh 2>&1); check "no tests -> exit 3" 3 $? "$out" "NO TESTS SET UP YET"
if python3 -m pytest --version >/dev/null 2>&1; then
  mkdir -p "$p/tests"; echo "pytest" > "$p/requirements.txt"
  printf 'def test_ok():\n    assert 1 + 1 == 2\n' > "$p/tests/test_ok.py"
  out=$(cd "$p" && bash scripts/test.sh 2>&1); check "passing pytest -> exit 0" 0 $? "$out" "RESULT: PASSED"
  printf 'def test_bad():\n    assert 1 + 1 == 3\n' > "$p/tests/test_bad.py"
  out=$(cd "$p" && bash scripts/test.sh 2>&1); code=$?; [ $code -ne 0 ] && [ $code -ne 3 ]; check "failing pytest -> real failure code" 0 $? "$out" "RESULT: FAILED"

  echo "== test gate (Stop hook)"
  (cd "$p" && git init -q -b main && git add -A && git -c user.email=t@t -c user.name=t commit -qm init)
  gate() { printf '%s' "$1" | CLAUDE_PROJECT_DIR="$p" bash "$p/.claude/hooks/test-gate.sh" 2>&1; }
  out=$(gate '{"stop_hook_active":false}'); check "gate blocks on failing tests" 2 $? "$out" "Tests are failing"
  out=$(gate '{"stop_hook_active":false}'); check "gate does not re-block unchanged failure" 0 $? "$out" "STILL failing"
  echo "# touch" >> "$p/tests/test_bad.py"
  out=$(gate '{"stop_hook_active":true}'); check "gate never loops" 0 $? "$out" "STILL failing"
  rm "$p/tests/test_bad.py"
  out=$(gate '{"stop_hook_active":false}'); check "gate passes when green" 0 $?
  [ -f "$p/.claude/.test-gate-pass" ]; check "gate records pass" 0 $?
  out=$(PROJECT_KIT_SKIP_TEST_GATE=1 gate '{}'); check "gate can be skipped" 0 $?
else
  echo "skip pytest-based checks (pytest not installed)"
fi

echo ""
echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
