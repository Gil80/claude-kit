---
name: bootstrap
description: Set up a new or existing project with the standard project-kit structure (CLAUDE.md, README, .env.example, test script, CI, verify skill, guardrails). Use when starting a new project, when the folder is empty, or when the session-start reminder says standard files are missing.
argument-hint: "[what you want to build]"
---

# Bootstrap a project

The user may be a "vibe coder" with no fixed stack or style. Keep questions few and plain, recommend sensible defaults, and do the work for them.

Idea from the user (may be empty): $ARGUMENTS

## Step 1: Look before touching anything
- Check the current folder: empty (new project) or existing code?
- If it's not a git repo, run `git init -b main`.
- If code exists, read enough to learn the stack, how it runs and how it's tested. Do not ask the user what you can find out yourself.

## Step 2: Ask only what you can't infer (one message, at most 4 questions)
For a new project:
1. What are you building, in one sentence? (skip if given above)
2. Who uses it, and where does it run (web app, API, script, mobile, desktop)?
3. Any stack preference? If not, recommend one with a one-line reason, favoring boring, popular, well-documented choices.
4. Will it need secrets (API keys, database)?

For an existing project, ask only about gaps (for example "how do you run it?" if nothing tells you).

## Step 3: Copy the standard files (never overwrites)
Run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/copy-template.sh" .
```
Show the user the CREATED / SKIPPED summary. For SKIPPED files that already existed (for example an old README), merge in what's missing from the template version instead of replacing them. The template copies are in `${CLAUDE_PLUGIN_ROOT}/template/`.

## Step 4: Fill in every TODO
- `CLAUDE.md`: name, what it is, stack, real run command, first decisions (with dates and reasons). Keep it under about 60 lines.
- `README.md`: prerequisites, fresh-clone setup, run, test.
- `.env.example`: every variable the app needs, placeholders only.
- `.claude/skills/verify/SKILL.md`: replace the TODO in step 2 with this project's real build and smoke checks.
- `scripts/test.sh`: if auto-detection doesn't fit this stack, replace it with the explicit commands. Keep the exit-code contract (0 pass, 3 no tests, other = fail).
- `.github/workflows/ci.yml`: add any setup step the stack needs (for example a database service).
- If the project needs local services, add a `docker-compose.yml` and document it in the README.
- Delete `TODO` lines that genuinely don't apply. No TODO may remain.

## Step 5: Make it verifiable from day one
- New project: scaffold the minimal app, then add at least one real test (a smoke test is fine).
- Existing project with no tests: add one test for the most important behavior.
- Run `bash scripts/test.sh` and show the real output. It must exit 0. Exit 3 means you're not done.

## Step 6: Record and finish
- In `.project-kit`, set `last_checkup=` to the output of `date +%s` (edit the file; keep `version` as is).
- Check `grep -rn "TODO" CLAUDE.md README.md .claude/ scripts/ .env.example` returns nothing that still needs the user.
- Suggest the user run `/memory` once to see that CLAUDE.md and the testing rule load.
- Offer (don't do without a yes) to make the first commit, and, if `gh` is installed and signed in, to create a private GitHub repo with `gh repo create <name> --private --source . --push`.

## Final report to the user
A short checklist: files created, TODOs filled, test command and its real result, what's still open. Plain language, no jargon.
