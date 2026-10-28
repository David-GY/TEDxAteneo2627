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

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD04, AD06.
- Provide the UI with plain-purpose author/assigned-reviewer/released-summary states and explicit anonymity/retention limits, preserving the fixed sensitive boundary.
- Keep optional module activation gated on actual recorded custodian/basis/retention; no mandatory feedback or new ordinary member navigation while disabled.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Implement round purpose/template/subject/reviewer/retention/release policy with explicit conflicts and reviewer assignments.
2. Keep author's submitted record immutable, append amendments, separate raw third-party feedback from released subject summary and apply holds/dispositions.
3. Require recorded custodian/basis/retention before real-data activation; use synthetic fixtures and explain anonymity limits.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P60_A1: Subject, mentor, PM and ordinary admin cannot read raw third-party feedback by knowing IDs or querying joins.
- P60_A2: Revoked/conflicted reviewer cannot submit/release; wrong-subject summary cannot be published.
- P60_A3: Restricted reads/downloads/export audit without raw text, and retention respects hold and backup replay.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P60_U1: Safe status/projection distinguishes submitted feedback from released subject summary without allowing subject/mentor/admin raw access by ref.
- P60_U2: Missing policy keeps the module inactive with actionable custodian prerequisites; no invented approval/anonymous guarantee or private text reaches telemetry.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P60.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
