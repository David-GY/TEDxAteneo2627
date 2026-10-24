# P33 — Manage roster, deployments, unit rename/merge/archive

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P33: Manage roster, deployments, unit rename/merge/archive.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F13/F22; section 6 organization changes.
Code/interface prerequisites: P32. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/organization/*; supabase/migrations/*organization_commands.sql; supabase/tests/unit_changes.test.sql

Interfaces / invariants:
Organization commands preview impact, preserve UUID/history, reassign active work explicitly and create aliases; deployments are scoped dated grants.

Implement and verify this bounded slice:
1. Build add/edit/archive unit and roster/deployment screens with active owners and service contacts. Avoid hardcoding the illustrative eight committees.
2. Implement rename/merge impact preview including open work, active reviewers and access deltas; old records preserve original unit identity.
3. Require replacement for orphaned active ownership/approval; merge does not silently union all privileges or move restricted case contents.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P33_A1: Renaming MCD/unit keeps original tracking IDs and deep links.
- P33_A2: Merge cannot unexpectedly grant another committee access to FIN/PRISM or historical private tasks.
- P33_A3: Archiving a head/unit with active cases either assigns an authorized replacement or leaves explicit blocked work.

Update docs/build/steps/P33.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
