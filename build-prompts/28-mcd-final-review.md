# P28 — Implement final publicity review with immutable evidence

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P28: Implement final publicity review with immutable evidence.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F10; section 10 approved snapshot.
Code/interface prerequisites: P23, P12, P26. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/publicity/*; supabase/migrations/*publicity_review.sql; supabase/tests/publicity_review.test.sql

Interfaces / invariants:
publicity_reviews bind final rendition manifest, copy/caption, credits, channel/use and intended date to request revision and MCD decision.

Implement and verify this bounded slice:
1. Build final-publicity intake/reviewer pages separate from draft creative collaboration. Require frozen app evidence or exported rendition plus source link.
2. Use explicit MCD capability and P22 decisions; govern asset/caption/credit/channel/use changes through new revision, preserving old approvals.
3. Expose safe MCD gate results and independent FIN requirement for cost-bearing publicity. Do not post to social accounts.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P28_A1: Mutable Canva/Drive URL alone cannot be accepted as final approval evidence.
- P28_A2: Caption-only or source-asset replacement invalidates current publication readiness.
- P28_A3: FIN approval cannot substitute for MCD, and MCD approval cannot clear unpaid/unapproved financial gates.

Update docs/build/steps/P28.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
