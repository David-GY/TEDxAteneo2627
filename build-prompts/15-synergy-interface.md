# P15 — Build Working Together and negotiation screens

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P15: Build Working Together and negotiation screens.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F04/F05; section 4 Working Together.
Code/interface prerequisites: P14, P13. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/synergies/WorkingTogetherPage.tsx; src/features/synergies/AgreementPage.tsx; src/features/deliverables/*

Interfaces / invariants:
UI uses P14 commands and displays same agreement in requesting/receiving committee views with versioned accepted terms.

Implement and verify this bounded slice:
1. Create outgoing/incoming agreements and contribution views, request-help form, accept/decline/counterproposal actions and clear pending ownership.
2. Add deliverable contributions panel and assigned work links; integrate accepted contributions in My Tasks/Overview.
3. Display proposed versus agreed deadlines and immutable history. Preserve mobile/keyboard usability.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P15_A1: Two scoped users see one agreement with correct actions rather than duplicated independent records.
- P15_A2: Receiver cannot edit other contributions/finance data through shared parent links.
- P15_A3: A failed/stale negotiation keeps entered safe data and offers refresh without fake success.

Update docs/build/steps/P15.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
