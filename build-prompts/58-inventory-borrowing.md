# P58 — Build SUS inventory reservation, checkout and return

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P58: Build SUS inventory reservation, checkout and return.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F17/F09; section 5 inventory.
Code/interface prerequisites: P33, P26, P46. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/inventory/*; supabase/migrations/*inventory.sql; supabase/tests/inventory.test.sql

Interfaces / invariants:
Item master, custodians and immutable quantity/condition movements; atomic reserve/issue/partial-return/cancel, FIN linkage for costs.

Implement and verify this bounded slice:
1. Add stock/borrower/dates/condition/location schema and authorized request/custodian screens with simple ledger rather than overwritable available count.
2. Implement concurrent reservation, physical issue confirmation, returns, partial returns and loss/damage notes with evidence.
3. Distinguish consumables from returnable items; route purchase/replacement costs to FIN and queue departed-custodian reassignment.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P58_A1: Simultaneous borrowers cannot reserve more than available and repeat return cannot inflate stock.
- P58_A2: Partial return/lost item yields consistent balance/condition/audit rather than silent negative inventory.
- P58_A3: Replacement expense cannot be approved by inventory role without FIN authority; unauthorized borrower details stay private.

Update docs/build/steps/P58.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
