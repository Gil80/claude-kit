# How to structure a repo for Claude Code

The reasoning behind claude-kit. It merges a widely shared checklist (Julio Casal's "How to Structure Your Repo for Claude Code") with corrections and additions that came up during review and testing.

## The core idea

Claude is only as reliable as the checks it can run. Everything here serves one goal: Claude can build the project, test it, and prove the result, without you having to remember any of it.

## The building blocks

### 1. CLAUDE.md: short, non-obvious facts
- Include commands, constraints and decisions Claude can't work out from the code. Keep it under about 60 to 80 lines.
- Point to README.md for setup rather than copying the steps, so the two can't drift apart.
- Long procedures go in skills, not here.
- Run the built-in `/doctor prompt-audit` (Claude Code 2.1.283+) after big changes or model upgrades. It flags stale, broken or conflicting instructions.

### 2. README.md + .env.example: the single source of truth for setup
- Prerequisites, fresh-clone setup, how to run, how to test.
- Variable names and placeholders only. Real values never go in git.
- Test it from a fresh clone. If a human gets stuck, Claude will too.

### 3. .claude/settings.json: rules that are enforced
- Shared permissions and hooks are committed. Personal overrides go in `settings.local.json` (gitignored).
- A sentence in CLAUDE.md is a suggestion, and a hook is enforced. "Always run tests" in CLAUDE.md can be ignored, but a Stop hook that runs them can't.
- Deny rules keep secrets out of Claude's context. Git-ignoring `.env` doesn't stop Claude from reading the local copy.
- Permission rules can't make exceptions, so `Read(./.env.*)` also blocks `.env.example`. List the real secret files explicitly instead. (Found by testing.)
- Claude Code protects writes inside `.claude/`. Files Claude must update itself, such as bookkeeping, belong outside it. (Found by testing.)

### 4. .claude/rules/: instructions scoped to parts of the codebase
- Use `paths:` frontmatter to scope a rule to matching files. The filename alone doesn't scope it.
- Rules without `paths` load in every session, so keep them few.
- The `paths` parser has had bugs that fail silently (GitHub issues #13905, #17204). Run `/memory` to confirm a rule really loads.

### 5. .claude/skills/: reusable procedures
- One folder per skill with a `SKILL.md`. Only the description loads up front, and the full instructions load when the skill is invoked.
- Start with `verify`: the exact commands to run and what counts as a pass.

### 6. Code structure: by feature, consistent names
- Group related code by feature and use names that describe the work (`CreateItemEndpoint.cs`, not `Endpoint.cs`).
- This is a team preference, not a Claude requirement. Consistency matters more than the particular pattern.

### 7. tests/: checks with a clear pass or fail
- Integration tests for API behavior (HTTP plus a real database).
- A regression test for every bug fix.
- "No tests" is not a pass. In claude-kit, `scripts/test.sh` exits 3 in that case.

### 8. scripts/ + CI: one command, everywhere
- `scripts/test.sh` works from a fresh clone and keeps the real failing exit codes.
- CI runs the same script. Require the CI checks before merging.

### 9. Also worth having (missing from the original checklist)
- `.mcp.json` to share tool connections (database, issue tracker).
- `.claude/agents/` for subagents such as a reviewer.
- `AGENTS.md` if you also use other AI coding tools.

## The mistakes to avoid
- Keeping instructions after the code has changed. Run a checkup monthly.
- Putting long, task-specific procedures in CLAUDE.md.
- Accepting "done" without seeing which commands ran, what failed and what was skipped.
- Assuming a rule or hook works without seeing it load and fire.

## How claude-kit makes this automatic

| Layer | Holds | Why there |
|---|---|---|
| Plugin (installed once per computer) | Session reminder, secret guard, bootstrap, checkup, reviewer | Same in every project; update once, every project benefits |
| Template (copied into each project) | Folder layout, test script, CI, hooks, rules, verify skill | Must live in the repo so it works in cloud sessions and for collaborators |
| Project (filled in by bootstrap) | Real commands, decisions, stack, project-specific checks | Unique to each project |

### Why one repo instead of a separate GitHub template repo
A separate template repo would duplicate the template stored in the plugin, and the two would drift apart. That is mistake number one above. A template repo also can't fill in TODOs, add a first test, or retrofit an existing project. `/project-kit:bootstrap` does all three, in any folder.
