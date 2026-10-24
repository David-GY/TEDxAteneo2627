# P02 — Define members, terms, units and scoped roles

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P02: Define members, terms, units and scoped roles.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Sections 3, 8 identity entities; F01/F13.
Code/interface prerequisites: P00. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/config.toml; supabase/migrations/*identity.sql; supabase/seed.sql; supabase/tests/identity.test.sql; src/lib/database.types.ts

Interfaces / invariants:
organizations, terms, members, term_memberships, private_profiles, org_units, unit_memberships, roles, role_permissions and role_assignments. Actor linkage is server controlled.

Implement and verify this bounded slice:
1. Initialize Supabase local configuration if absent, verify the target is local, and document Docker/CLI prerequisites. Add foundational identity/organization tables with real FKs, same-term checks, unique normalized identity, active/expired states, dated deployments and role assignments. Enable RLS/revoke exposed grants immediately; P03 adds permitted policies.
2. Keep committee delivery flags separate from service flags. MEAn affiliation is nullable descriptive data. Defer work-item scope FK until P07 rather than adding dangling references.
3. Seed clearly fictional local roles/members/units, not an invented official eight. Generate database types and document the identity contracts.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P02_A1: Cross-term membership/unit links fail and duplicate normalized identities are rejected.
- P02_A2: Changing MEAn affiliation creates no authorization change or new role assignment.
- P02_A3: Fresh local migration/seed succeeds and all foundational tables have appropriate initial deny-by-default exposure.

Update docs/build/steps/P02.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
