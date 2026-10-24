# P44 — Build workload, readiness and meaningful-usage reports

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P44: Build workload, readiness and meaningful-usage reports.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F21; section 14 metrics.
Code/interface prerequisites: P43, P29. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/reports/*; supabase/migrations/*reports.sql; docs/analytics.md

Interfaces / invariants:
Scoped SQL reports use documented event allowlist and Monday–Sunday Manila periods; minimal first-party events, no sensitive bodies.

Implement and verify this bounded slice:
1. Implement readiness, overdue/original dates, blocked duration, queue age, handoff/approval turnaround and assigned workload with clear definitions.
2. Add meaningful weekly active numerator/eligible-core denominator, excluding guests/tests/bots; instrument safe work views/actions and retention for usage events.
3. Restrict supervisory breakdowns and exports; no public member ranking, affiliation comparison or fake utilization percentages.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P44_A1: At 89 eligible members, at least 72 meaningful active members meets 80%; logins/bot pings alone do not.
- P44_A2: Multi-unit users are counted once and Manila week boundary is correct.
- P44_A3: Changing deadline does not erase original overdue history; small/private groups do not reveal protected records.

Update docs/build/steps/P44.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
