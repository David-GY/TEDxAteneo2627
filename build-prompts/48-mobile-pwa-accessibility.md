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

Implement and verify this bounded slice:
1. Add manifest/install affordance and useful offline state without caching authenticated APIs, files, OAuth callbacks or private drafts.
2. Audit 320px/zoom, visible focus/contrast, modal focus, labels/errors, screen-reader updates and keyboard alternatives in actual essential flows.
3. Fix discovered barriers in shared components and targeted screens; capture real screenshots/check results with synthetic data. Do not redesign the app.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P48_A1: Signing out/offline cannot expose previous user's finance/task payload or service-worker cache.
- P48_A2: Keyboard-only user completes task, handoff and review; mobile controls remain 44px and usable at 200% zoom.
- P48_A3: Automated axe plus manual evidence recorded; no blanket WCAG certification based only on an automated scan.

Update docs/build/steps/P48.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
