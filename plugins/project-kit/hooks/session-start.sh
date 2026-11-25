#!/usr/bin/env bash
# project-kit SessionStart hook.
# Prints plain text on stdout; Claude Code adds it to the session context.
# Goal: you never have to remember the standards. Claude reminds you.
set -u

input="$(cat 2>/dev/null || true)"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1 | tr -d '\r'; }
kit_version="$(kv "$plugin_root/template/.project-kit" version)"
[ -n "$kit_version" ] || kit_version=unknown

# Not a project folder: stay quiet.
case "$dir" in
  "$HOME" | "/" | "") exit 0 ;;
esac
[ -f "$dir/.project-kit-ignore" ] && exit 0

# Is this folder effectively empty (a brand new project)?
visible="$(ls -A "$dir" 2>/dev/null | grep -v -E '^(\.git|\.DS_Store|\.claude|\.idea|\.vscode)$' | head -n 1)"

# Existing project that never ran bootstrap: stay quiet. Only new (empty) folders get the offer.
[ -n "$visible" ] && [ ! -f "$dir/.project-kit" ] && exit 0

missing=""
for f in .project-kit CLAUDE.md README.md .gitignore .env.example scripts/test.sh .claude/settings.json .claude/skills/verify/SKILL.md; do
  [ -e "$dir/$f" ] || missing="$missing $f"
done
ci_found="no"
for wf in "$dir"/.github/workflows/*.yml "$dir"/.github/workflows/*.yaml; do
  [ -f "$wf" ] && ci_found="yes"
done
[ "$ci_found" = "no" ] && missing="$missing .github/workflows/(ci)"

echo "[project-kit $kit_version] Working agreements for this session:"
echo "- Done means verified: run the project's test command (scripts/test.sh if present) and show the real output. State plainly what was not verified or was skipped."
echo "- Never read, print or commit real secrets (.env files, keys). New variables go in .env.example with placeholders."
echo "- Prefer small, reviewable steps. Add a regression test with every bug fix."
echo "- If a decision or command changes, update CLAUDE.md in the same change."

if [ -z "$visible" ]; then
  echo ""
  echo "[project-kit] This folder is EMPTY, so it looks like a brand new project."
  echo "In your first reply, before anything else, tell the user in one or two sentences and offer to run /project-kit:bootstrap to set up the standard structure (CLAUDE.md, README, tests, CI, guardrails). Keep it short and friendly."
  exit 0
fi

if [ -n "$missing" ]; then
  echo ""
  echo "[project-kit] This project is missing parts of the standard setup:$missing"
  echo "In your first reply, before other work, mention this in one short sentence and offer /project-kit:bootstrap (it only adds missing files, never overwrites). If the user declines for good, offer to create an empty .project-kit-ignore file in the project root to silence this reminder. Do not nag again in this session."
  exit 0
fi

# Fully set up: check freshness.
notes=""
proj_version="$(kv "$dir/.project-kit" version)"
[ -n "$proj_version" ] || proj_version=none
if [ "$proj_version" != "$kit_version" ]; then
  notes="$notes\n- The project's standards are version $proj_version, the current kit is $kit_version. Suggest /project-kit:checkup to pull in improvements."
fi
last="$(kv "$dir/.project-kit" last_checkup | tr -cd '0-9')"
now="$(date +%s)"
if [ -z "$last" ] || [ $((now - last)) -gt 2592000 ]; then
  notes="$notes\n- No checkup in the last 30 days. Suggest /project-kit:checkup to catch stale instructions and drift."
fi
if [ -n "$notes" ]; then
  echo ""
  echo "[project-kit] Maintenance (mention once, briefly, at a natural moment; do not block the user's task):"
  printf "%b\n" "$notes" | sed '/^$/d'
fi
exit 0
