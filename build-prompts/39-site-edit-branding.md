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

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD05, AD06, AD07.
- Keep a stable small everyday navigation grouped by member task; role-only tools stay separate, and disabled optional modules have no links/setup nags. Contextual Edit Mode is visibly different from using the app; use the common P35 save/preview/publish pattern with safe unsaved-change recovery.
- Allow approved wording changes with preview on ordinary member, head and guest layouts; retain deep links, first-use acronym explanations, approved identity text and access enforcement. Fix the no-space mobile text identity without inventing a licensed logo.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Implement authenticated contextual Edit Mode for supported text/link/card blocks, navigation wording/order, guide copy and branding tokens.
2. Add draft/preview/diff/publish/revert and role-aware synthetic previews. Keep licensed logo shape/name/color protected by approved-asset selection and MCD review record.
3. Check contrast and focus visibility; keep Karla/calm tokens by default. No arbitrary HTML/CSS/JavaScript injection or fresh decorative redesign.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P39_A1: Typing in Edit Mode is private until publish and rollback records a new version.
- P39_A2: Renaming labels does not break deep links, workflow semantics or permission keys.
- P39_A3: Unsafe block content or inaccessible token combination is rejected/warned with a concrete repair; ordinary members cannot enter editor.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P39_U1: A navigation/wording publication preserves current short refs, old deep links, restricted destinations and an obvious first-work/help route for the intended role.
- P39_U2: Leaving/refreshing editor mode cannot silently discard or publish a draft; an ordinary member cannot enter editor mode, and disabled modules stay absent from both navigation and mandatory setup.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P39.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
