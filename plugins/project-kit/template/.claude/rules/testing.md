---
paths:
  - "tests/**"
  - "test/**"
  - "**/__tests__/**"
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/*_test.*"
  - "**/test_*.py"
---

# Testing rules

- Test behavior the user cares about, not implementation details.
- Every bug fix starts with a test that fails before the fix and passes after it.
- No real network calls, real secrets or shared state in unit tests. Use fakes.
- For APIs, prefer integration tests that go through HTTP and the real database (or a local container).
- Never skip, delete or weaken a failing test to get green. If a test is wrong, say why and fix it openly.
- `bash scripts/test.sh` must pick up any new test file automatically. If it doesn't, fix the script.
