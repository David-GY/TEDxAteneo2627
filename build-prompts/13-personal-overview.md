# P13 — Build next actions and Who is waiting on you

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P13: Build next actions and Who is waiting on you.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F02; section 4 Overview.
Code/interface prerequisites: P10, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/overview/*; supabase/migrations/*overview_queries.sql

Interfaces / invariants:
Authorized overview result separates actionable work from waiting-on-others and supports later request/handoff/approval sources.

Implement and verify this bounded slice:
1. Aggregate real assigned due/overdue/blocked work and owned deliverables with next action/person/date. Integrate only sources already implemented, not invented pending approvals.
2. Add sensible empty/error/loading states, direct authorized links and committee context.
3. Define small source extensions so P18/P23/P30 add handoffs/reviews/inbox without duplicating counts or bypassing scopes.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P13_A1: Widget count equals its visible actionable rows.
- P13_A2: Restricted work does not leak through aggregate totals or hidden titles.
- P13_A3: An action completed elsewhere disappears after real invalidation/refetch; no hardcoded demo numbers.

Update docs/build/steps/P13.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
