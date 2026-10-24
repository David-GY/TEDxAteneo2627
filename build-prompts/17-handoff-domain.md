# P17 — Implement immutable handoff packages and acceptance

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P17: Implement immutable handoff packages and acceptance.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F06; section 6 accept_handoff.
Code/interface prerequisites: P16, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*handoffs.sql; supabase/tests/handoffs.test.sql; src/features/handoffs/api.ts

Interfaces / invariants:
submit_handoff, respond_to_handoff and accept_handoff bind receiver, package revision/manifest, criteria and agreed next task.

Implement and verify this bounded slice:
1. Store offered package snapshots, sender/receiver, due date, states and resubmission revisions. Sender remains responsible until explicit acceptance.
2. Make acceptance atomic with immutable receipt, scoped grants and activation of the next agreed task; keep deliverable owner unchanged.
3. Recheck current receiver authority and original package state; audit transitions and emit outbox events.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P17_A1: Changed file source cannot silently change the offered snapshot.
- P17_A2: Accept racing cancellation has one valid outcome, not two contradictory states.
- P17_A3: Decline/revision request creates no next task; repeated successful acceptance does not duplicate work.

Update docs/build/steps/P17.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
