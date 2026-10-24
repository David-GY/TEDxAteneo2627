# P60 — Create restricted evaluation rounds, submissions and release rules

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional sensitive module

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P60: Create restricted evaluation rounds, submissions and release rules.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F16; section 3 feedback; section 11 retention.
Code/interface prerequisites: P22, P46, P47. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*evaluations.sql; supabase/tests/evaluations.test.sql; src/features/evaluations/api.ts

Interfaces / invariants:
feedback_rounds/submissions/revisions/reviewer notes and separate evaluation_releases; audited restricted RPC reads, no broad table SELECT.

Implement and verify this bounded slice:
1. Implement round purpose/template/subject/reviewer/retention/release policy with explicit conflicts and reviewer assignments.
2. Keep author's submitted record immutable, append amendments, separate raw third-party feedback from released subject summary and apply holds/dispositions.
3. Require recorded custodian/basis/retention before real-data activation; use synthetic fixtures and explain anonymity limits.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P60_A1: Subject, mentor, PM and ordinary admin cannot read raw third-party feedback by knowing IDs or querying joins.
- P60_A2: Revoked/conflicted reviewer cannot submit/release; wrong-subject summary cannot be published.
- P60_A3: Restricted reads/downloads/export audit without raw text, and retention respects hold and backup replay.

Update docs/build/steps/P60.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
