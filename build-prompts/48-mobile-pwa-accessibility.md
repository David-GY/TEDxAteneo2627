# P48 — Verify essential mobile flows and add a safe PWA shell

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P48: Verify essential mobile flows and add a safe PWA shell.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F25; section 11 accessibility; section 14 tests.
Code/interface prerequisites: P47. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/app/*; public/manifest.webmanifest; service-worker configuration; tests/e2e/accessibility.spec.ts; docs/accessibility.md

Interfaces / invariants:
Installable shell caches public assets only; responsive and keyboard behavior applies to implemented work/review/admin flows.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD02, AD04, AD05, AD06, AD09.
- Reaudit and repair current essential work/request/review/onboarding/admin journeys, including open AD findings, at320px,200%zoom,keyboard and relevant assistive technology. Audit hierarchy/labels/error recovery as well as geometry; do not defer barriers from earlier steps until now.
- Install/offline states explain a useful next step without caching private APIs/files/drafts. Verify the complete mobile navigation including More and long renamed labels meets the44CSS-pixel house target without overflow.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Add manifest/install affordance and useful offline state without caching authenticated APIs, files, OAuth callbacks or private drafts.
2. Audit 320px/zoom, visible focus/contrast, modal focus, labels/errors, screen-reader updates and keyboard alternatives in actual essential flows.
3. Fix discovered barriers in shared components and targeted screens; capture real screenshots/check results with synthetic data. Do not redesign the app.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P48_A1: Signing out/offline cannot expose previous user's finance/task payload or service-worker cache.
- P48_A2: Keyboard-only user completes task, handoff and review; mobile controls remain 44px and usable at 200% zoom.
- P48_A3: Automated axe plus manual evidence recorded; no blanket WCAG certification based only on an automated scan.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P48_U1: Representative member/guest/head essential journeys remain understandable and operable with keyboard/mobile/zoom; record open failures by AD ID rather than claiming certification from axe alone.
- P48_U2: No required action/help is clipped, hidden behind optional setup or dependent on drag; all five bottom targets meet the house target and offline/sign-out cannot expose the previous account.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P48.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
