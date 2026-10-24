# P61 — Build PRISM desk, released summaries and safe aggregates

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional sensitive module

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P61: Build PRISM desk, released summaries and safe aggregates.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F16/F21; section 14 privacy tests.
Code/interface prerequisites: P60, P43, P44. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/evaluations/*; src/features/reports/*; tests/e2e/evaluations.spec.ts

Interfaces / invariants:
UI consumes restricted P60 APIs; author/assigned-reviewer/subject-release views distinct; aggregation suppresses groups below five and reconstructive filters.

Implement and verify this bounded slice:
1. Build feedback submission, assigned PRISM queue, attributable reviewer notes, controlled summary review/release and subject-visible results.
2. Add explicit export control and minimum-group reporting; prevent differencing/drilldown that reconstructs identities.
3. Publish clear anonymity/rights/retention text, route formal complaints to approved school process, and verify no raw content enters global search or notifications.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P61_A1: Subject sees only released summary; author edits produce a revision, not overwritten submitted evidence.
- P61_A2: Groups under five and difference-of-filters reconstruction cannot expose individuals.
- P61_A3: Real sensitive activation stays blocked without actual owner/policy/UAT; screenshots and test fixtures contain synthetic data only.

Update docs/build/steps/P61.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
