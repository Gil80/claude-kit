---
name: checkup
description: Health check for a project's Claude setup. Finds stale instructions, missing or outdated standard files, broken test or CI commands, and drift from the current project-kit template. Use monthly, after big changes, after a model upgrade, or when the session-start reminder suggests it.
---

# Project checkup

Report first, change second. Never overwrite the user's content without showing the change and getting a yes.

## 1. Compare against the current template
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/copy-template.sh" . --diff
cat .project-kit 2>/dev/null; cat "${CLAUDE_PLUGIN_ROOT}/template/.project-kit"
```
- MISSING files: offer to add them (`copy-template.sh .` adds only missing files).
- DIFFERS files: `.project-kit` always differs, ignore it. Most others will differ on purpose (filled-in TODOs). Only flag differences in the *machinery*: `.claude/hooks/*`, `.github/workflows/ci.yml` structure, `.gitignore` secret rules, `.claude/settings.json` deny rules and hooks, and the exit-code contract in `scripts/test.sh`. Show a short diff and propose merging improvements while keeping the project's own changes.

## 2. Is CLAUDE.md still true?
- Every command it mentions: does it exist and work? Run the test command for real.
- Every file or folder it mentions: does it exist?
- Do the Stack and Decisions sections match the code (package files, imports, folder layout)?
- Leftover TODOs, contradictions, or long step-by-step procedures that belong in a skill?
- Over about 80 lines? Propose what to cut or move.

## 3. Does the safety net work?
- `bash scripts/test.sh` exits 0 and actually runs tests (look for real counts, not exit 3).
- `.github/workflows/ci.yml` calls `bash scripts/test.sh`.
- `.gitignore` covers `.env` and `.claude/settings.local.json`; `git ls-files | grep -E '(^|/)\.env($|\.)' | grep -v example` returns nothing.
- `.claude/rules/*.md` `paths:` globs match real files in this repo (list a few matches).
- The verify skill has no TODO left and its checks match the stack.

## 4. Report, then fix with permission
Give a table: area, status (OK / needs fix), what you found. Then offer the fixes as one batch. After applying any accepted fixes, run `bash scripts/test.sh` again and show the result.

## 5. Record it
- Edit `.project-kit`: set `version=` to the version in `${CLAUDE_PLUGIN_ROOT}/template/.project-kit`, and `last_checkup=` to the output of `date +%s`.
- Remind the user they can also run the built-in `/doctor prompt-audit` for a second opinion on instruction quality (you can't run built-in slash commands yourself).
