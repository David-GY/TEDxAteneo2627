# P29 — Unify deliverable acceptance across contributions and approvals

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P29: Unify deliverable acceptance across contributions and approvals.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F03/F05/F09/F10; section 4 readiness.
Code/interface prerequisites: P18, P26, P27, P28. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*readiness.sql; supabase/tests/readiness.test.sql; src/features/deliverables/*; src/features/overview/*

Interfaces / invariants:
Authoritative readiness/accept_deliverable checks required contribution acceptance, tasks/dependencies, criteria, valid revision-bound FIN/MCD and external authorization.

Implement and verify this bounded slice:
1. Implement safe gate aggregation and derived readiness categories without treating task-percent complete as acceptance.
2. Wire deliverable owner submission and authorized final acceptance to actual checks; update list/detail/overview next action and blockers.
3. Apply protected policy triggers on work type even if an admin removes/renames a workflow label; record explicit permitted scope exceptions separately.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P29_A1: All tasks Done with required handoff or FIN/MCD pending cannot accept deliverable.
- P29_A2: A formerly accepted deliverable affected by a governed change shows required re-review according to documented reopening rule.
- P29_A3: Unauthorized user learns no confidential amount/title through blocked reasons; clean authorized example completes end to end.

Update docs/build/steps/P29.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
