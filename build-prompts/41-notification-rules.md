# P41 — Configure notification rules, schedules and preferences

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P41: Configure notification rules, schedules and preferences.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F19/F22; section 6 notification settings.
Code/interface prerequisites: P40, P30. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/notifications/*; src/features/notifications/preferences/*; supabase/functions/notification-scheduler/*

Interfaces / invariants:
Rules select fixed events/audiences/channels with dedup, bounded schedule and Manila quiet hours; delivery preference does not remove required work.

Implement and verify this bounded slice:
1. Add admin rules, recipient dry-run, safe templates, due/overdue reminders, digest/mute choices and channel availability.
2. Implement default two-days-before/due-day/daily-overdue scheduling and 20:00–08:00 quiet period as editable proposals, using tested Manila dates.
3. Use durable deduplication and outbox dispatch; external channels remain disabled until configured/verified in optional steps.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P41_A1: Scheduler retry/window overlap creates no duplicate digest or reminder.
- P41_A2: Muted external delivery does not hide the in-app pending obligation.
- P41_A3: Recipient preview respects access; private payload cannot be inserted into external-message templates.

Update docs/build/steps/P41.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
