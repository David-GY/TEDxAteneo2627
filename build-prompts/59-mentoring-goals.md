# P59 — Build opt-in goals and scoped mentor check-ins

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P59: Build opt-in goals and scoped mentor check-ins.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F15; section 3 goals and mentoring.
Code/interface prerequisites: P06, P32, P46. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/growth/*; supabase/migrations/*mentoring.sql; supabase/tests/mentoring.test.sql

Interfaces / invariants:
mentorships have approved effective dates; owned goals/sharing and author-attributed check-ins are separate from evaluations.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD02, AD05, AD06.
- Keep goals/check-ins a small optional experience with clear sharing/withdrawal and current named mentor, separate from evaluations and core work navigation when disabled.
- Use attributable notes, readable next check-in and safe unsaved-change recovery; avoid mandatory personal disclosure or calendar connection.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Build goals, target/progress and sharing choice, assigned-mentor list, check-in schedule/actions and attributable notes.
2. Enforce relationship expiry/reassignment and withdrawal of sharing; mentor cannot edit mentee's goal wording or read evaluation cases.
3. Connect private check-in calendar only through permitted audience/explicit opt-in export; apply category retention and member export.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P59_A1: Former mentor with live session loses access after relationship expiry/revoke.
- P59_A2: Head/PM/PRISM roles have no automatic raw goal access unless explicit appropriate grant.
- P59_A3: Private check-in title/notes do not leak through core calendar/search/reports.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P59_U1: A member can identify who sees a goal and withdraw sharing without losing unrelated work; former mentor loses access even with a live session.
- P59_U2: Empty goals/disconnected calendar offer a useful optional path and no onboarding block; private check-in content remains absent from broad search/reports/calendar.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P59.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
