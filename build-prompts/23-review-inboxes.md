# P23 — Build department triage and reviewer decision screens

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P23: Build department triage and reviewer decision screens.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08/F02; section 4 Department Inbox.
Code/interface prerequisites: P22, P18. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/approvals/*; src/features/requests/*; src/features/overview/*

Interfaces / invariants:
Authorized queue and assignment/decision UI use P22, exposing only reviewable version and permissible actions.

Implement and verify this bounded slice:
1. Implement unassigned/assigned/aging/revision inboxes, reviewer assignment, requested versus accepted dates and safe triage notes.
2. Add review package preview, required reasons, revise/reject/approve/complete as allowed by server, and reassignment of lost authority.
3. Integrate actionable reviews and revisions into overview; distinguish operational request approval from FIN authorization and MCD release.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P23_A1: Department associate sees assigned cases only unless explicitly granted broader scope.
- P23_A2: Revoked reviewer loses action immediately after DB authorization check, even with an open page.
- P23_A3: UI shows server conflict/validation and never optimistically labels a failed decision approved.

Update docs/build/steps/P23.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
