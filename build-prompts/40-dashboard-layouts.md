# P40 — Configure widgets and layouts by role

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P40: Configure widgets and layouts by role.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22/F02; section 6 widget catalog.
Code/interface prerequisites: P39, P30, P31. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/layouts/*; src/features/overview/*; src/app/widgetCatalog.ts

Interfaces / invariants:
Role/unit layout config selects fixed widget IDs and supported options; each widget independently queries authorized data.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD04, AD06, AD09.
- Provide a useful default home prioritizing next action, owner/date and blockers, with optional secondary widgets behind purposeful groups. No member must personalize a dashboard before work; do not show all widgets at equal emphasis.
- Layout preview must cover a late joiner/no work, a current assignee, a head and a guest using coherent fixtures. Preserve required actions/help,320px/zoom/keyboard behavior and independently authorized widget queries.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Implement role layouts, responsive placement/order/size, saved operational views and preview. Provide keyboard Move Up/Down, not drag-only controls.
2. Offer existing task/waiting/deliverables/synergy/review/calendar/resource widgets only; optional-module widgets appear only when enabled.
3. Retain a required route/action path so layout cannot hide all next actions; prevent arbitrary SQL/query definition.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P40_A1: A member cannot obtain FIN data by adding a FIN widget to a layout.
- P40_A2: Same layout remains usable on 320px screen and with keyboard reordering.
- P40_A3: Missing/retired widget produces a clear safe fallback and configuration validation, not a broken dashboard.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P40_U1: Fresh/no-work and retired-widget layouts retain a direct current contact/assigned-work path; adding/reordering widgets cannot hide all next actions or manufacture FIN/guest access.
- P40_U2: The same representative next-action journey remains discoverable across default/custom/mobile layouts with44px controls; saved configuration does not require member setup or duplicate authoritative work.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P40.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
