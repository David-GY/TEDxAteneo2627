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

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD02, AD04, AD05, AD06.
- Use separate focused author, assigned-reviewer and subject-release journeys, each with one clear next action and plain privacy/help text. Keep raw/released material unmistakably distinct.
- Reuse safe revision/input/recovery controls and scoped export confirmation; formal complaints point to the approved process and no required ordinary-work setup is added.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Build feedback submission, assigned PRISM queue, attributable reviewer notes, controlled summary review/release and subject-visible results.
2. Add explicit export control and minimum-group reporting; prevent differencing/drilldown that reconstructs identities.
3. Publish clear anonymity/rights/retention text, route formal complaints to approved school process, and verify no raw content enters global search or notifications.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P61_A1: Subject sees only released summary; author edits produce a revision, not overwritten submitted evidence.
- P61_A2: Groups under five and difference-of-filters reconstruction cannot expose individuals.
- P61_A3: Real sensitive activation stays blocked without actual owner/policy/UAT; screenshots and test fixtures contain synthetic data only.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P61_U1: A subject sees and understands only the released summary; authors can append a revision without silently overwriting evidence, and failure/retry preserves safe inputs.
- P61_U2: Clear labels/filter choices cannot reconstruct suppressed groups or widen raw access; actual sensitive privacy/UAT remains required, not satisfied by synthetic screenshots.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P61.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
