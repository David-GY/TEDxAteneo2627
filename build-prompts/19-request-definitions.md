# P19 — Create versioned request types and initial service catalog

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P19: Create versioned request types and initial service catalog.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08/F22; section 6 form/workflow definitions.
Code/interface prerequisites: P07, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*request_definitions.sql; src/features/requests/catalog/*; supabase/tests/request_definitions.test.sql

Interfaces / invariants:
request_types points to immutable form_versions/workflow_versions, receiving service, primary/backup contacts and guest eligibility.

Implement and verify this bounded slice:
1. Define stable request/form/stage identifiers and bounded schema types matching section 6. Seed general, FIN and MCD configurations with unconfirmed authority clearly flagged.
2. Build a plain-language catalog/read-only published form definition query and contact/lead-time/official-link display.
3. Protect typed financial/approval fields from arbitrary ordinary JSON and keep confidential custom fields restricted by type/payload classification.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P19_A1: Published schema cannot be edited in place and an archived service cannot receive new live requests.
- P19_A2: Unknown/conflicting field keys or unsafe executable conditions are rejected.
- P19_A3: No generic form-definition read exposes private financial data, secrets or case notes.

Update docs/build/steps/P19.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
