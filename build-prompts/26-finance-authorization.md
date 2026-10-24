# P26 — Enforce independent FIN authorization and revision invalidation

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P26: Enforce independent FIN authorization and revision invalidation.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F09; section 6 material-change rules.
Code/interface prerequisites: P25. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*financial_authorization.sql; supabase/tests/financial_authorization.test.sql; src/features/finance/*

Interfaces / invariants:
FIN decision creates financial_authorization for exact revision/ceiling/purpose/conditions/expiry with required external authorization status.

Implement and verify this bounded slice:
1. Connect typed FIN capability to P22. Block requester/beneficiary self-approval, require officially authorized alternate, and support partial approval without altering request.
2. Implement governed changes/new revision and superseded/expired/revoked authorization state with old decision preserved.
3. Build FIN decision/conditions/ceiling view and external evidence/not-required policy outcome. No invented threshold or PM substitute.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P26_A1: Sole FIN approver's own case pauses rather than self-approves or routes to an unauthorized PM.
- P26_A2: Amount/purpose/pricing/quantity/evidence change invalidates old readiness; harmless excluded metadata does not silently rewrite evidence.
- P26_A3: Concurrent approve/reject or retry records one valid transition and preserves original request amount.

Update docs/build/steps/P26.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
