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

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD03, AD04, AD06.
- Use one consistent display model for Not required, Waiting for review, Approved for this revision and Unavailable; named statuses cannot override authoritative semantics. Show active phase dates and actual permitted primary/backup help routes in member-facing process pages.
- For newly configured ordinary tracking namespaces, require a unique recognizable short prefix(default2-6uppercase letters); separate it from mutable unit labels and retain old long prefixes/issued references permanently. Validate the existing allocator namespace, alias and collision rules rather than renumbering historical requests.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Add phase management and current-phase display; validate active phase selection and date order without assuming prototype phase names.
2. Add status-label/color/order editor with protected semantics and accessible contrast; cannot turn a pending state into an approved decision.
3. Add service name/description, receiving unit, primary/backup contacts, official form link, lead-time text and guest eligibility with impact validation.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P38_A1: Renamed PRISM/status/phase does not change authority, routes or historical meaning.
- P38_A2: Invalid phase date range or inactive required contact is reported before publish.
- P38_A3: A status called Approved without a valid decision still fails readiness; published copy updates through versioned config.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P38_U1: Changing a display status/phase/service name cannot change required approvals, reference or old pinned meaning; all relevant cards agree on gate applicability without revealing private cases.
- P38_U2: New short prefix collisions/unsafe reserved FIN-MCD namespaces are refused; old long refs and renamed-unit aliases still resolve only within current access. Missing contacts provide a concrete permitted repair route and cannot appear live-ready.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P38.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
