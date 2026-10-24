# P25 — Build cost and fundraising/sales request experiences

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P25: Build cost and fundraising/sales request experiences.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F09; section 6 FIN defaults.
Code/interface prerequisites: P24, P23. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/finance/FinanceRequestForm.tsx; src/features/finance/FinanceCasePage.tsx; src/features/finance/FinanceDesk.tsx

Interfaces / invariants:
Typed intake and reviewer detail use P24, showing requested/forecast/authorized/actual as distinct concepts.

Implement and verify this bounded slice:
1. Build itemized cost/expense forms and fundraising/sales plan forms with prices, quantities, projected revenue/costs, terms, purpose and school evidence requirements.
2. Show confidential case contents only to eligible participants; show neutral gate summary to ordinary deliverable participants.
3. Explain that submission authorizes no commitment/payment and zero-cost fundraising still requires FIN review; expose missing requirements clearly.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P25_A1: Zero-cost fundraiser takes FIN path rather than skipping approval.
- P25_A2: Partial-line edits recompute exact totals with useful field errors.
- P25_A3: Shared task link exposes safe status, never receipts, amounts or private financial title.

Update docs/build/steps/P25.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
