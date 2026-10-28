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

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD02, AD06.
- Separate manager reports from the everyday next-action home. Place concise metric definitions/time period/denominator beside the report; prefer actionable scoped summaries over dense default charts or rankings.
- Use readable titles/refs and authorized drill-through for a manager investigation. Keep usage telemetry minimal; learnability results are actual UAT records, not a score inferred from login/activity.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Implement readiness, overdue/original dates, blocked duration, queue age, handoff/approval turnaround and assigned workload with clear definitions.
2. Add meaningful weekly active numerator/eligible-core denominator, excluding guests/tests/bots; instrument safe work views/actions and retention for usage events.
3. Restrict supervisory breakdowns and exports; no public member ranking, affiliation comparison or fake utilization percentages.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P44_A1: At 89 eligible members, at least 72 meaningful active members meets 80%; logins/bot pings alone do not.
- P44_A2: Multi-unit users are counted once and Manila week boundary is correct.
- P44_A3: Changing deadline does not erase original overdue history; small/private groups do not reveal protected records.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P44_U1: A scoped head can explain a representative blocked/overdue metric and open only its permitted source work; no raw payload, small-group identity or public member ranking leaks.
- P44_U2: Zero data, stale data and unsupported filters produce an understandable safe state rather than fake percentages; operational activity is never relabeled newcomer task success.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P44.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
