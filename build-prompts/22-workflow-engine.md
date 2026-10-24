# P22 — Execute authorized sequential review workflows

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P22: Execute authorized sequential review workflows.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08/F09/F10; section 6 workflow engine and transition_request.
Code/interface prerequisites: P21. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*workflow_engine.sql; supabase/tests/workflow_engine.test.sql; src/features/approvals/api.ts

Interfaces / invariants:
transition_request supports assigned sequential stages with one/all reviewers, pinned workflow/revision, revision route, conditions and external evidence; actor is session-derived.

Implement and verify this bounded slice:
1. Implement assignments and append-only decisions; lock current stage/revision, check effective role, independence, expiry, required documents and idempotency.
2. Advance only after configured quorum; missing/revoked approver pauses for authorized reassignment. Stage labels do not change protected semantics.
3. Commit business state, decision, safe outcome, audit and outbox together. FIN/MCD typed authority hooks fail closed until their modules are installed.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P22_A1: Unassigned/self/revoked approver, direct status update and stale-revision action fail.
- P22_A2: All-reviewer stage cannot advance after only one decision; duplicate retries do not count twice.
- P22_A3: Failed transition rolls back all effects; pinned old workflow remains consistent after new publication.

Update docs/build/steps/P22.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
