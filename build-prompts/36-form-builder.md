# P36 — Build the no-code request form editor

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P36: Build the no-code request form editor.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22; section 6 Form builder.
Code/interface prerequisites: P35, P20. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/forms/*; src/features/forms/*; supabase/tests/form_publication.test.sql

Interfaces / invariants:
Editor produces the same FormDefinition accepted by P20, preserving stable keys/options and routing confidential payloads correctly.

Implement and verify this bounded slice:
1. Implement field/section add/edit/reorder/remove-draft, supported types, help, required conditions, options and repeatable lines with keyboard controls.
2. Add synthetic preview and schema validation; enforce limits and fixed operators. Reserved finance/approval values remain typed protected fields.
3. Publish through P35; show impact on drafts and explicit migration rather than changing submitted data. Explain why confidential fields need restricted storage/type.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P36_A1: Renaming a label does not change stored field key/old answer meaning.
- P36_A2: A confidential custom field cannot publish into broad ordinary JSON.
- P36_A3: Published old form submissions remain readable under their version; unsafe condition/code and excessive schema size fail.

Update docs/build/steps/P36.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
