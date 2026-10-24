# P31 — Build the shared calendar and explicit event exports

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P31: Build the shared calendar and explicit event exports.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F12; section 10 Calendar.
Code/interface prerequisites: P30. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/calendar/*; supabase/migrations/*calendar.sql; src/features/calendar/ics.test.ts

Interfaces / invariants:
calendar_events preserve source/visibility; single-event ICS and Add to Google Calendar are explicitly copies, not live sync.

Implement and verify this bounded slice:
1. Build month/list/mobile event views with permitted core/committee events and source-linked milestones/deadlines.
2. Implement accurate Manila timed/all-day export, escaping ICS content, updates/cancellation labels and no duplicate source events.
3. Keep private finance/feedback/mentoring details out of shared calendars and defer automatic Google API integration to P53.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P31_A1: Manila midnight, all-day dates and cancellation export correctly without date shifts.
- P31_A2: Guest/other-unit user cannot see private event title/location through calendar counts.
- P31_A3: Add-to-calendar is labeled copy and never claims continuous synchronization.

Update docs/build/steps/P31.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
