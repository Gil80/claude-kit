#!/usr/bin/env bash
# project-kit PreToolUse hook: keeps real secrets out of Claude's context.
# Blocks Read/Edit/Write of .env files and private keys, and Bash commands
# that would print them. Templates like .env.example are allowed.
# Best effort, not a sandbox: it catches the common accidents.
set -u

input="$(cat)"

field() { # field <name>: extract a top-level-ish string field from the hook JSON
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg k "$1" '.[$k] // .tool_input[$k] // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c 'import sys,json
k=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
v=d.get(k) or (d.get("tool_input") or {}).get(k) or ""
print(v)' "$1" 2>/dev/null
  else
    printf '%s' "$input" | tr '\n' ' ' | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
  fi
}

is_allowed_template() { # .env.example and friends are fine
  case "$1" in
    *.example | *.sample | *.template | *.dist | *.defaults) return 0 ;;
  esac
  return 1
}

is_secret_path() {
  base="$(basename "$1")"
  is_allowed_template "$base" && return 1
  case "$base" in
    .env | .env.* | .envrc | *.pem | *.p12 | *.pfx | id_rsa | id_rsa.* | id_ed25519 | id_ed25519.* | id_ecdsa | id_ecdsa.*) return 0 ;;
  esac
  return 1
}

block() {
  echo "Blocked by project-kit secret guard: $1" >&2
  echo "Do not read or print real secrets. Use .env.example for variable names, and ask the user to edit the real file themselves if a value must change." >&2
  exit 2
}

tool="$(field tool_name)"
case "$tool" in
  Read | Edit | Write | MultiEdit | NotebookEdit)
    path="$(field file_path)"
    [ -z "$path" ] && path="$(field notebook_path)"
    [ -n "$path" ] && is_secret_path "$path" && block "$tool on $(basename "$path")"
    ;;
  Bash)
    cmd="$(field command)"
    [ -z "$cmd" ] && exit 0
    # Only care about commands that would show file contents.
    if printf '%s' "$cmd" | grep -Eq '(^|[^A-Za-z0-9_])(cat|less|more|head|tail|bat|grep|egrep|rg|awk|sed|source|xxd|od|strings|base64|nl|tac|curl|scp|type|Get-Content)([^A-Za-z0-9_]|$)|(^|[;&|[:space:]])\.[[:space:]]'; then
      for tok in $(printf '%s' "$cmd" | grep -oE "(^|[[:space:]\"'/<=])(\.env[A-Za-z0-9._-]*|\.envrc|[A-Za-z0-9._-]*\.pem|id_(rsa|ed25519|ecdsa))" | sed -E "s/^[[:space:]\"'\/<=]//"); do
        is_secret_path "$tok" && block "command would expose $tok"
      done
    fi
    ;;
esac
exit 0
