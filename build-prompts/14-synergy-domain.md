# P14 — Implement versioned committee synergy agreements

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P14: Implement versioned committee synergy agreements.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F04; section 6 propose_synergy/respond_to_synergy.
Code/interface prerequisites: P09, P10. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*synergy.sql; supabase/tests/synergy.test.sql; src/features/synergies/api.ts

Interfaces / invariants:
propose_synergy and respond_to_synergy support accept/decline/counterproposal against immutable agreement_revisions, creating named contributions on agreement.

Implement and verify this bounded slice:
1. Model requester/receiver units, output, criteria, effort band, date, named owner and revision confirmations. Grant receiving heads only a safe proposal preview.
2. Require valid receiving-head authority and requester acceptance of counters. Accepted terms are immutable; material changes negotiate a revision.
3. Create canonical contribution/grants/tasks transactionally; no duplicate copies per committee and no implicit whole-parent access.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P14_A1: Counterproposal does not activate work before requester confirms that revision.
- P14_A2: Unrelated head or expired role cannot accept; unknown owner/cross-term links fail.
- P14_A3: Concurrent accept/retry produces one contribution and one audit/outbox result.

Update docs/build/steps/P14.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
