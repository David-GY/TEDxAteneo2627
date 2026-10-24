# P38 — Edit phases, semantic statuses and service routing

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P38: Edit phases, semantic statuses and service routing.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22/F08; section 6 configuration table.
Code/interface prerequisites: P37. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/phases/*; src/features/admin/statuses/*; src/features/admin/services/*

Interfaces / invariants:
Admin controls edit display labels/order, phase dates and service contacts while stable IDs/semantic categories remain authoritative.

Implement and verify this bounded slice:
1. Add phase management and current-phase display; validate active phase selection and date order without assuming prototype phase names.
2. Add status-label/color/order editor with protected semantics and accessible contrast; cannot turn a pending state into an approved decision.
3. Add service name/description, receiving unit, primary/backup contacts, official form link, lead-time text and guest eligibility with impact validation.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P38_A1: Renamed PRISM/status/phase does not change authority, routes or historical meaning.
- P38_A2: Invalid phase date range or inactive required contact is reported before publish.
- P38_A3: A status called Approved without a valid decision still fails readiness; published copy updates through versioned config.

Update docs/build/steps/P38.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
