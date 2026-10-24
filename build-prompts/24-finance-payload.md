# P24 — Create restricted finance revisions and exact money calculations

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P24: Create restricted finance revisions and exact money calculations.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F09; section 8 finance entities.
Code/interface prerequisites: P22, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*finance_payload.sql; supabase/tests/finance_payload.test.sql; src/features/finance/money.ts

Interfaces / invariants:
finance_cases/revisions/lines and audited restricted reads separate from ordinary request JSON; PHP amounts use integer centavos and defined quantity rounding.

Implement and verify this bounded slice:
1. Model costs, budget/expenses/reimbursement and fundraising/sales plan payloads, fund/purpose/beneficiary, pricing, forecast and governed evidence.
2. Implement trusted line/total validation with explicit quantity scale/rounding and safe serialization; never binary floating money. Keep sensitive joins out of ordinary views.
3. Bind finance revision to submitted request revision and immutable private evidence; define payload hash fields for later authorizations.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P24_A1: PHP 0.10 + 0.20 equals 0.30; inconsistent totals, negative invalid inputs and out-of-range values fail.
- P24_A2: Ordinary head/member cannot read another FIN case through API/search/counts/attachments.
- P24_A3: Forecast sales do not create actual revenue or a payment record; source payload remains immutable.

Update docs/build/steps/P24.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
