# P46 — Implement privacy notice, restricted access logs and retention controls

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P46: Implement privacy notice, restricted access logs and retention controls.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F16/F24/F26; section 11 privacy/retention.
Code/interface prerequisites: P45, P34. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/privacy/*; supabase/migrations/*retention.sql; supabase/functions/privacy-requests/*; docs/privacy-and-retention.md

Interfaces / invariants:
Versioned privacy notice, category retention_rules, legal_holds, auditable access/export and timed emergency grants; routine private reads use audited restricted endpoints.

Implement and verify this bounded slice:
1. Build notice/optional sharing acknowledgments, custodian request intake, authorized access/correction/export handling, retention policy configuration and hold review.
2. Implement dry-run disposition/purge planning without running live deletion; distinguish archive from erasure, preserve necessary minimal ledger and restore replay.
3. Add time-bounded emergency access with reason/notification and no routine broad admin contents. Block sensitive-module activation without owner/basis/retention decisions.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P46_A1: Legal hold prevents scheduled disposal and dry-run lists affected records/files without exposing their contents.
- P46_A2: Admin cannot silently self-grant indefinite raw FIN/PRISM access through UI.
- P46_A3: All normal restricted reads/exports are logged through authorized endpoints; raw sensitive payloads/tokens do not enter telemetry.

Update docs/build/steps/P46.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
