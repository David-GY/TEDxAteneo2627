# P62 — Implement verified term freeze, archive and successor handover

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Required turnover

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P62: Implement verified term freeze, archive and successor handover.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F24/F26; sections 7/11 turnover and retention.
Code/interface prerequisites: P45, P46, P47, P33, P29. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/turnover/*; supabase/migrations/*term_closure.sql; supabase/functions/archive/*; docs/turnover.md

Interfaces / invariants:
freeze_term and run_archive create resumable scoped manifests, records/files dispositions and verification; new-term roles are explicitly regranted.

Implement and verify this bounded slice:
1. Build closure checklists per unit/deliverable, unresolved obligation resolution/carry-forward, freeze, classified archive plan and legal holds.
2. Implement resumable records/config/file export with counts/hashes/errors and actual restore sample, plus successor acceptance/custody checklist.
3. Preserve raw FIN/PRISM boundaries; revoke outgoing scopes only through named transfer workflow. Rehearse synthetically now; do not freeze the live term or purge real data just to test.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P62_A1: Missing file/failed hash/unfinished export cannot show turnover complete.
- P62_A2: Frozen term rejects ordinary mutation while controlled correction/retention operations remain audited.
- P62_A3: Successor gets explicitly granted records, not automatic raw evaluations; every record has archive/dispose/hold/carry disposition.

Update docs/build/steps/P62.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
