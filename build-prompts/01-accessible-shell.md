# P01 — Recreate the prototype navigation and visual shell

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P01: Recreate the prototype navigation and visual shell.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Section 4; F25; section 11 branding.
Code/interface prerequisites: P00. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/app/AppShell.tsx; src/app/navigation.ts; src/styles/tokens.css; src/styles/global.css; DESIGN.md

Interfaces / invariants:
Create reusable accessible page, panel, form/error and navigation patterns; expose role-filterable navigation without treating it as authorization.

Implement and verify this bounded slice:
1. Inspect the supplied demo or its locally available source and preserve Karla, neutral palette, compact panels, interface accent and focus language; record tokens in DESIGN.md.
2. Implement desktop/sidebar and mobile labeled navigation, skip link, headings, keyboard focus, route-level loading/empty/error states. Use an approved logo asset if supplied; otherwise a plainly labeled temporary text identity.
3. Make synthetic preview content explicitly development-only; do not ship fake success buttons or recreate all feature pages now.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P01_A1: Shell works at 320px width and 200% zoom with keyboard navigation and visible focus.
- P01_A2: 44px controls and meaningful accessible names survive long unit/person labels.
- P01_A3: Route errors show a recovery action; production routes do not display synthetic metrics as real data.

Update docs/build/steps/P01.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
