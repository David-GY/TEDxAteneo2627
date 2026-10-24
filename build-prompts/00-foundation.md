# P00 — Create the runnable project and build ledger

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P00: Create the runnable project and build ledger.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Sections 1, 8 conventions, 9; F25/F26.
Code/interface prerequisites: None; initial step. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
package.json; src/main.tsx; src/app/router.tsx; .env.example; .gitignore; docs/build/STATE.md; docs/build/CONTRACTS.md

Interfaces / invariants:
Establish working npm scripts typecheck, lint, test, build and later test:e2e; record real commands and runtime prerequisites. No placeholder scripts returning success.

Implement and verify this bounded slice:
1. Inspect existing repo/runtime; scaffold Vite React/TypeScript only if no app exists. Keep dependency choices small, preserve unrelated files, and ignore secrets/build artifacts.
2. Add an app route, error boundary, environment validation with a useful not-configured screen, and one meaningful mount/configuration test. Add a fake-free local README.
3. Create state/checkpoint conventions and contracts for UUID IDs, Manila dates, structured command errors, expectedVersion and idempotencyKey. Document PostgreSQL as the authority and synthetic staging boundaries.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P00_A1: Clean dependency install and actual typecheck/lint/test/build pass; an unavailable runtime is a recorded blocker, never a passing check.
- P00_A2: App boots locally with no credentials without exposing secrets or pretending to load real work.
- P00_A3: Repository has no committed secrets and state identifies P01 as next; application code only changes within this foundation.

Update docs/build/steps/P00.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
