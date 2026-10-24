# P09 — Add deliverable ownership, criteria and acceptance commands

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P09: Add deliverable ownership, criteria and acceptance commands.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F03; section 6 create_deliverable.
Code/interface prerequisites: P08. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/deliverables/DeliverableEditor.tsx; supabase/migrations/*deliverable_commands.sql; supabase/tests/deliverables.test.sql

Interfaces / invariants:
create_deliverable and update_deliverable require active owner, lead unit, outcome, date and criteria; acceptance evaluates server readiness.

Implement and verify this bounded slice:
1. Build authorized create/edit/propose/reassign flows; preserve original deadline and reasoned changes. Members propose commitments for heads rather than assigning arbitrary people.
2. Implement draft/in-progress/submit-for-acceptance/accept/cancel with typed semantic states. Until P29, fail closed when unresolved mandatory gates exist.
3. Capture acceptance criteria revisions and final evidence; owner departure queues reassignment rather than silently becoming ownerless.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P09_A1: Inactive/cross-term owner rejected; ordinary member cannot create a top-level event commitment directly.
- P09_A2: Original deadline survives a later extension and change is attributed.
- P09_A3: Direct API completion or acceptance with unmet criteria/gates fails; an authorized clean case succeeds.

Update docs/build/steps/P09.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
