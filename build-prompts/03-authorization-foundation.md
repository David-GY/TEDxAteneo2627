# P03 — Implement and test identity authorization boundaries

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P03: Implement and test identity authorization boundaries.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Section 3; F01/F26; section 11 controls.
Code/interface prerequisites: P02. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*authorization.sql; supabase/tests/authorization.test.sql; docs/permissions.md

Interfaces / invariants:
Current-membership and effective-capability helpers derive auth.uid(); narrowly granted SQL functions use fixed search_path and no untrusted metadata.

Implement and verify this bounded slice:
1. Enable RLS and minimal grants for identity/unit/role tables; separate permitted directory projection from private profiles. Add safe read helpers and role assignment restrictions.
2. Prevent member edits to auth linkage, grant scope, expiry, organization and private-profile visibility belonging to someone else. Treat project-owner bypass as documented infrastructure risk.
3. Create authenticated-principal fixtures for PM/head/member/associate/guest; add negative tests and a concise permission explanation contract. No UI or service-role-only proof.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P03_A1: Same-domain nonmember, expired guest and suspended member read no workspace rows even with valid identity.
- P03_A2: Equivalent MEAn/non-MEAn grants yield identical results; deployment grants only the configured unit.
- P03_A3: Direct API attempts to self-grant roles or read another private profile fail; allowed writes assert the actual changed row.

Update docs/build/steps/P03.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
