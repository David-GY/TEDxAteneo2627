# P08 — Build the Core Deliverables list and detail view

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P08: Build the Core Deliverables list and detail view.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F03; section 4 Core Deliverables.
Code/interface prerequisites: P06, P07. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/deliverables/api.ts; src/features/deliverables/DeliverablesPage.tsx; src/features/deliverables/DeliverablePage.tsx; supabase/migrations/*deliverables.sql

Interfaces / invariants:
deliverables subtype and permission-filtered list/detail queries with owner, lead unit, date, readiness, next action and safe gate fields.

Implement and verify this bounded slice:
1. Add deliverable child schema and real queries, including pagination/filter state and stable deep links. Seed one clearly synthetic shared-output example locally.
2. Implement required columns, phase/unit/owner/blocked/overdue/involves-my-unit filters, mobile rows, loading/error/empty states.
3. Use provisional pending-gate states until P29 installs authoritative acceptance; no client-generated approval badges or completion percentages masquerading as readiness.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P08_A1: Restricted deliverables and private details are absent from unauthorized rows/counts.
- P08_A2: Multi-unit filter uses one canonical output without duplicating it.
- P08_A3: List/detail render real DB changes and provide a useful state for no records or denied deep links.

Update docs/build/steps/P08.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
