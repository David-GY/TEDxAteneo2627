# P47 — Implement encrypted backup and prove identity/file recovery

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P47: Implement encrypted backup and prove identity/file recovery.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F24/F26; section 11 recovery.
Code/interface prerequisites: P46, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
scripts/backup/*; scripts/restore/*; docs/recovery.md; src/features/admin/health/*

Interfaces / invariants:
Backup manifest covers app data/config, schema, file bytes/hashes, identity linkage recovery, retention/purge replay and separate key custody; freshness visible to custodians.

Implement and verify this bounded slice:
1. Implement documented encrypted export and verify tools' actual Auth/Storage inclusion/exclusion. Keep backups/secrets out of Git artifacts and ordinary member folders.
2. Add restoration into an explicitly verified isolated local/authorized recovery target; preserve stable member IDs or test verified provider re-linking.
3. Rehearse login, permissions, immutable decisions/files and purge replay; record actual RPO/RTO, missing prerequisites and second-custodian runbook. Do not invent a successful rehearsal.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P47_A1: Restored user can log in to correct scope; unauthorized user cannot read recovered private files.
- P47_A2: Manifest counts/file hashes match and expired/purged data does not silently resurrect.
- P47_A3: Stale/failed backup appears in health; missing device/provider/key makes verification blocked, not green.

Update docs/build/steps/P47.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
