# claude-kit

My standard setup for every coding project with Claude Code. Install it once and Claude reminds me to use it, so I don't have to remember anything.

## Install (once per computer)

Run in a terminal:

```bash
claude plugin marketplace add Gil80/claude-kit
```

```bash
claude plugin install project-kit@claude-kit
```

Or inside Claude Code: `/plugin marketplace add Gil80/claude-kit`, then `/plugin install project-kit@claude-kit`.

## Daily use

1. Make an empty folder and open Claude Code in it.
2. Claude notices the folder is empty and offers to set it up. Say yes, or type `/project-kit:bootstrap <what you want to build>`.
3. Build as usual. Claude can't finish a turn while tests are failing, and it can't read your `.env`.
4. About once a month Claude suggests `/project-kit:checkup`. Say yes.

## What's inside

| Piece | What it does | Where |
|---|---|---|
| Session reminder | Empty folder: offers bootstrap. Bootstrapped project (has `.project-kit`): shares the working agreements, flags missing standard files, suggests a checkup if stale or behind the kit version. Any other existing project: silent |  `plugins/project-kit/hooks/session-start.sh` |
| Secret guard | Blocks Claude from reading or printing `.env` files and private keys, in every project | `plugins/project-kit/hooks/secret-guard.sh` |
| `/project-kit:bootstrap` | Adds the standard files (never overwrites), fills in the TODOs, adds a first test and runs it | `plugins/project-kit/skills/bootstrap/` |
| `/project-kit:checkup` | Finds stale instructions, broken commands and drift from the current template | `plugins/project-kit/skills/checkup/` |
| `reviewer` agent | Fresh-eyes review of a change before committing | `plugins/project-kit/agents/reviewer.md` |
| Project template | The files every project gets (below) | `plugins/project-kit/template/` |

### What every project gets

```
CLAUDE.md                    short project facts and decisions
README.md                    setup, run, test (the one source of truth)
.env.example                 variable names with placeholders
.gitignore                   secrets and personal Claude files ignored
.project-kit                 kit version and last checkup date
scripts/test.sh              one test command: 0 = pass, 3 = no tests yet, other = fail
.github/workflows/ci.yml     CI runs the same scripts/test.sh
.claude/settings.json        deny rules for secrets, Stop hook, auto-enables this plugin
.claude/hooks/test-gate.sh   Claude can't stop while tests it touched fail
.claude/rules/testing.md     testing rules, loaded only for test files
.claude/skills/verify/       /verify: what "it works" means for this project
```

The project's own files work without the plugin (in cloud sessions, or for collaborators). The plugin adds the reminders, the secret guard and the bootstrap and checkup skills.

## Changing the standards

1. Edit files under `plugins/project-kit/template/` or the skills.
2. Bump `version` in both `plugins/project-kit/template/.project-kit` and `plugins/project-kit/.claude-plugin/plugin.json`.
3. Run `bash tests/run.sh`, then commit and push.
4. On each computer: `claude plugin marketplace update claude-kit`. Existing projects get nudged to run `/project-kit:checkup`, which merges the improvements.

## Escape hatches

- Silence reminders in one project: create an empty `.project-kit-ignore` file in its root.
- Skip the test gate for one session: `export PROJECT_KIT_SKIP_TEST_GATE=1` before starting Claude.

## Background

See [docs/GUIDE.md](docs/GUIDE.md) for the reasoning behind every piece.
