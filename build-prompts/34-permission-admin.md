# P34 — Build safe role editing and access explanations

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P34: Build safe role editing and access explanations.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22/F26; section 3 matrix.
Code/interface prerequisites: P33. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/access/*; supabase/migrations/*delegation.sql; supabase/tests/delegation.test.sql

Interfaces / invariants:
Role administration chooses fixed resource/action/scope capabilities, dated assignments and delegation ceilings; preview explains effective access without real impersonation.

Implement and verify this bounded slice:
1. Build roles/permission grid, unit/record scope assignment, expiry, revoke and audit history for authorized grantors.
2. Protect last super admin, sensitive-review capabilities, emergency access boundary and no self-escalation; distinguish app roles from provider-console ownership.
3. Provide synthetic role preview and access-explanation results with current grants/mandatory constraints; no administrative read-all endpoint.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P34_A1: Delegated head cannot grant FIN/PRISM/admin beyond grantor ceiling or edit own privileges upward.
- P34_A2: Last technical custodian cannot be removed without a verified replacement path.
- P34_A3: Membership/role expiry is honored immediately; synthetic preview cannot expose another user's real sensitive record.

Update docs/build/steps/P34.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
