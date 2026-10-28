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

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD04, AD06.
- Explain each rule as event, audience, channel and time with a no-send recipient preview. Group useful updates and link directly to the permitted action; use clear saved/muted/delivery-unavailable states rather than another task queue.
- Keep scheduling code/test proposals separate from live cadence activation. Existing no-schedule/no-external-message instructions remain unless separately authorized; mute and missing channels never hide the authoritative in-app obligation.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Add admin rules, recipient dry-run, safe templates, due/overdue reminders, digest/mute choices and channel availability.
2. Implement default two-days-before/due-day/daily-overdue scheduling and 20:00–08:00 quiet period as editable proposals, using tested Manila dates.
3. Use durable deduplication and outbox dispatch; external channels remain disabled until configured/verified in optional steps.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P41_A1: Scheduler retry/window overlap creates no duplicate digest or reminder.
- P41_A2: Muted external delivery does not hide the in-app pending obligation.
- P41_A3: Recipient preview respects access; private payload cannot be inserted into external-message templates.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P41_U1: A permitted recipient can identify the actual next action from a grouped in-app alert; mute/retry/quiet-hour overlap cannot duplicate obligations or obscure still-pending work.
- P41_U2: Rule preview sends nothing and reveals no hidden recipients/payload; unconfigured channels show a useful fallback and do not generate connection nags for ordinary members.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P41.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
