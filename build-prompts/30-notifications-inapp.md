# P30 — Deliver deduplicated in-app notifications and reliable jobs

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P30: Deliver deduplicated in-app notifications and reliable jobs.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F19; section 6 outbox contracts.
Code/interface prerequisites: P29. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/notifications/*; supabase/functions/dispatch-notifications/*; supabase/tests/notifications.test.sql

Interfaces / invariants:
Transactional outbox -> authorized notifications with unique recipient/event key, read state, retries, dead-letter visibility and current access checks.

Implement and verify this bounded slice:
1. Implement inbox/badge and required actionable events from tasks, agreements, handoffs, requests and decisions; handle already-resolved actions.
2. Dispatch after commit with bounded backoff, idempotency and persistent failure status. Keep external adapters disabled until their own steps.
3. Add read/unread preferences skeleton and safe notification text for restricted cases; prevent stale content after access revocation.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P30_A1: Job crash/retry creates one visible notification, not duplicates.
- P30_A2: Business decision remains committed if dispatch fails; failed queue is visible to custodian.
- P30_A3: Revoked member cannot read stale restricted notification or use a deep link to regain access.

Update docs/build/steps/P30.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
