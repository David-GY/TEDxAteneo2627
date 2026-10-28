# P53 — Implement one-way core-calendar publishing

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P53: Implement one-way core-calendar publishing.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F12; section 10 Calendar sync.
Code/interface prerequisites: P49, P31, P30. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/calendar/*; supabase/functions/calendar-sync/*; supabase/migrations/*calendar_mappings.sql

Interfaces / invariants:
App remains authoritative; explicit core-safe app events map to one approved core calendar, with source version, remote IDs, tombstones and durable token lifecycle.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD04, AD05, AD06.
- Distinguish Add a copy from verified automatic sync; show the last successful update and plain repair status. Connection is optional, with useful local app calendar when disabled/revoked.
- Use readable event titles and named authorized calendar selection; keep external edits/conflicts understandable without implying private events are shared.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Implement separately authorized connection and explicit app-to-Google publish/update/cancel jobs; document external-edit conflict policy.
2. Add idempotent mapping, retry/backoff, revoked-auth repair, last-sync/error view, and safe token storage. No private task/mentee/finance data in general calendar.
3. If reconciliation reads use incremental tokens, handle HTTP410 by rebuilding mapped remote cache without deleting canonical app events.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P53_A1: Create/update/retry/cancel results in one correctly timed remote event, no resurrection after tombstone.
- P53_A2: Expired/testing/revoked token shows stale state and fallback; never claims synced after failure.
- P53_A3: Private event/export preferences cannot leak through shared calendar title/description/location.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P53_U1: A failed/revoked sync cannot say current/synced, and retry/cancellation cannot duplicate or resurrect the event; the local next-action calendar remains usable.
- P53_U2: Declining sync adds no mandatory member setup, and private event/ref/title cannot leak through a broad calendar or repair preview.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P53.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
