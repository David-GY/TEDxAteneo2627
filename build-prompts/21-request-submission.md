# P21 — Implement tracked submission, revisions and requester views

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P21: Implement tracked submission, revisions and requester views.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08; section 8 requests/tracking counters.
Code/interface prerequisites: P20, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/requests/*; supabase/migrations/*request_submission.sql; supabase/tests/request_submission.test.sql

Interfaces / invariants:
submit_request allocates shared per-term/service namespace IDs, freezes validated payload/asset manifest and creates pinned workflow instance; revise_request appends revision.

Implement and verify this bounded slice:
1. Create requests, immutable revisions, tracking_counters and current state with same-term integrity. All FIN types share FIN counter, all MCD types share MCD counter.
2. Build draft/save/submit/revise/cancel/my-requests/tracking detail with next action, requested/accepted dates and history.
3. Pin form/workflow versions and create workflow assignment shell; P22 provides decision execution. Keep unconfigured authority visibly paused.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P21_A1: Concurrent different MCD form submissions cannot both emit MCD-027; IDs never recycle.
- P21_A2: Retry creates one submission; newer form publication does not rewrite prior payload/schema.
- P21_A3: Another requester cannot read/edit private request data; submitted revision is immutable.

Update docs/build/steps/P21.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
