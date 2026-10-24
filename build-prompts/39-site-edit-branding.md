# P39 — Implement general site Edit Mode, labels and branding

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P39: Implement general site Edit Mode, labels and branding.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22/F25; section 11 brand/accessibility.
Code/interface prerequisites: P38, P01. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/site/*; src/features/admin/branding/*; src/app/*; src/styles/tokens.css

Interfaces / invariants:
Site pages use safe block catalog and label/theme config via P35; approved-logo asset separate from interface font/accent.

Implement and verify this bounded slice:
1. Implement authenticated contextual Edit Mode for supported text/link/card blocks, navigation wording/order, guide copy and branding tokens.
2. Add draft/preview/diff/publish/revert and role-aware synthetic previews. Keep licensed logo shape/name/color protected by approved-asset selection and MCD review record.
3. Check contrast and focus visibility; keep Karla/calm tokens by default. No arbitrary HTML/CSS/JavaScript injection or fresh decorative redesign.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P39_A1: Typing in Edit Mode is private until publish and rollback records a new version.
- P39_A2: Renaming labels does not break deep links, workflow semantics or permission keys.
- P39_A3: Unsafe block content or inaccessible token combination is rejected/warned with a concrete repair; ordinary members cannot enter editor.

Update docs/build/steps/P39.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
