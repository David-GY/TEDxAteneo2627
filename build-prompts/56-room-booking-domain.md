# P56 — Implement conflict-safe Logistics room booking

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P56: Implement conflict-safe Logistics room booking.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F11; section 8 rooms/bookings.
Code/interface prerequisites: P22, P31, P38. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*room_booking.sql; supabase/tests/room_booking.test.sql; src/features/rooms/api.ts

Interfaces / invariants:
confirm_booking enforces official evidence and database exclusion over room/buffered half-open range for confirmed/persisted active holds.

Implement and verify this bounded slice:
1. Model rooms/accessibility/equipment and requests, expiring holds, confirmation and cancellation with Logistics authority.
2. Expire stale holds in confirmation transaction and serialize competing transitions; a worker is not sole protection against stuck holds.
3. Require external school reservation evidence or official not-required policy; create calendar source only for confirmed room.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P56_A1: Two concurrent overlapping confirmations cannot both succeed; adjacent nonbuffered slots behave correctly.
- P56_A2: Expired hold cannot block indefinitely if scheduler is down; setup/cleanup buffers count.
- P56_A3: Request submission or a calendar event alone cannot masquerade as official room reservation.

Update docs/build/steps/P56.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
