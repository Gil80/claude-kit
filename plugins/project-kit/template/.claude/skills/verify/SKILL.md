---
name: verify
description: Prove the project actually works before calling a task done. Use after changing code, before committing, or when the user asks whether something works.
---

# Verify

Run these in order. Stop at the first failure, fix it, and start again.

1. **Tests:** `bash scripts/test.sh`
   - Exit 0 = pass. Exit 3 = no tests exist yet, which is NOT a pass. Anything else = fail.
2. **Project-specific checks:** TODO (filled in by /project-kit:bootstrap). Examples:
   - Build: `npm run build` must exit 0.
   - Smoke test: start the app, request the main page or a health endpoint, expect HTTP 200.
3. **Changed behavior:** exercise the specific thing that changed (call the endpoint, run the command, open the page) and look at the real result.

## Report back in this format

- **Commands run:** each command and its exit code
- **Results:** passed / failed / skipped counts, quoted from the real output
- **Not verified:** anything you could not check, and why
- **Verdict:** PASS only if every step above passed. Otherwise FAIL, with the reason.

Never claim a pass you did not see in the output.
