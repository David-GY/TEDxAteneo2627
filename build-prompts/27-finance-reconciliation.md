# P27 — Add budget reservations and recorded actuals

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P27: Add budget reservations and recorded actuals.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F09/F21; section 8 budget ledger.
Code/interface prerequisites: P26. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*finance_ledger.sql; supabase/tests/finance_ledger.test.sql; src/features/finance/Reconciliation.tsx

Interfaces / invariants:
Optional budget_accounts and immutable reservation/release/reconciliation entries; actual expense/revenue records require evidence and do not process payments.

Implement and verify this bounded slice:
1. Implement configured budget ceilings with atomic reservation on authorization, explicit cancellation release and reversing entries rather than destructive edits.
2. Record authorized actual expenses/revenue and evidence; detect duplicates and overrun requiring new review. Label booked/forecast/actual distinctly.
3. Expose restricted FIN ledger and safe delivery gate outcome without publishing balances/receipts to general core.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P27_A1: Two simultaneous requests cannot reserve more than enabled available budget.
- P27_A2: Cancelled authorization releases once; retry and reversal cannot double-credit budget.
- P27_A3: Overrun is flagged/re-reviewed; projected sales never count as actual receipts and no payment integration exists.

Update docs/build/steps/P27.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
