# P20 — Render and validate configured request forms

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P20: Render and validate configured request forms.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08/F22; section 6 Form builder specification.
Code/interface prerequisites: P19. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/forms/*; supabase/functions or SQL validators; src/features/forms/validation.test.ts

Interfaces / invariants:
FormDefinition and typed field/condition evaluator supports fixed operators; browser and trusted submit validation agree on required fields and classifications.

Implement and verify this bounded slice:
1. Implement accessible fields: text, numeric/currency, dates, choice/multichoice, checkbox, eligible member/unit, URL, file, repeatable lines.
2. Add required/help/error handling and bounded AND/OR equality/membership/numeric conditions. Preserve stable option IDs and display snapshots.
3. Implement trusted validation, field/section/line caps, eligible selector validation and handling of values in newly hidden fields. Do not trust client hidden values.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P20_A1: Required conditional field omitted via direct API fails; client/server accept the same valid case.
- P20_A2: 50-field/10-section/100-line proposed limits and bounded condition nesting are enforced.
- P20_A3: Keyboard/screen-reader errors target the correct control; malicious scripts/regex definitions never execute.

Update docs/build/steps/P20.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
