# P35 — Repair everyday workflows and implement shared configuration publication

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P35: Repair everyday workflows and implement shared configuration publication.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22; section 6 configuration contract.
Also read docs/build/ADOPTION-DELIVERY.md, docs/readiness.md, docs/tasks.md, docs/resources-onboarding.md and docs/access-administration.md for the current equivalent interfaces; P34 mutation is delivered locally, not an absent prerequisite.
Code/interface prerequisites: P34, P19. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/config/*; supabase/migrations/*config_versions.sql; supabase/tests/config_publish.test.sql

Interfaces / invariants:
publish_configuration(expectedVersion, idempotencyKey) creates immutable version; rollback creates a new version and revalidates privilege/invariants.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD02, AD04, AD05, AD06, AD07, AD08, AD09.
- Batch35-R1, before new configuration screens: simplify the existing Overview, deliverable/task detail, request status and Resources entry paths. Show a specific permitted next action/owner/date/blocker first; open editing deliberately, group files/activity/verification separately, and reconcile Not required versus Pending versus Unavailable across readiness and FIN/MCD panels. Explain routine actions in plain language; retain applicable warnings and immutable evidence. Use existing src/features/{overview,deliverables,tasks,requests,resources,files} and scoped gate APIs; change a projection only if needed to carry authorized applicability, never infer permission from a hidden panel.
- Batch35-R2: repair safe in-memory edit preservation or explicit discard confirmation across refresh/conflict/uncertain retry; retain idempotency and account/scope clearing. Restore one coherent synthetic member/head/guest first-work preview using existing components, with tasks gateway enabled and fictional assigned work/process contacts. Keep the fixture banner and no-real-provider limitation. Provide direct first-work/help actions, separate publisher tools, and repair the320px More target to the44CSS-pixel house minimum without overflow.
- Batch35-R3, only after R1/R2 local checks: reuse P34 security commands, give their UI understandable permission/scope/name/date and impact-review language, and separate real publication from inspection/simulation. Do not rebuild lineage/custody enforcement. Then implement the original shared configuration draft/validate/preview/publish/history slice below using the same bounded editor pattern. P35 may require several CONTINUE executions; record R1/R2/R3 separately.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Establish supported configuration kinds and draft storage, version history, diff, validation, synthetic preview and explicit publish.
2. Validate same-term references, capability ceilings, reserved semantics and required gates before activation; preserve pinned historical requests.
3. Add conflict handling for simultaneous editors and canonical audit/outbox publication. No arbitrary JSON console bypass for business users.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P35_A1: Invalid/missing references or removed mandatory FIN/MCD gate cannot publish.
- P35_A2: Two administrators cannot overwrite each other's published version silently.
- P35_A3: Rollback preserves intervening history and never rewrites open cases' pinned workflow/schema.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P35_U1: An ordinary member and a head can locate title, owner/date and the actual permitted next action without traversing unrelated editors; nonfinancial work consistently says review not required while governed/pending/unavailable work remains distinct. Hidden case titles/counts are never exposed.
- P35_U2: Edit then refresh/back/conflict/timeout keeps safe inputs or obtains explicit discard intent; identical retry cannot duplicate an effect, and sign-out/scope loss clears the prior account state. Verify existing security/state tests still pass.
- P35_U3: The coherent synthetic preview supports assigned-task discovery, scoped help and sandbox practice with the real components; guest cannot browse the roster, and practice creates no task/request/FIN/outbox. Record desktop/mobile role coverage, not a human usability pass.
- P35_U4: Plain-language named access-impact review preserves exact scope/expiry/ceilings and independently acknowledged custody. At320px the five mobile primary targets meet44px house sizing without horizontal overflow; technical proofs remain available through scoped details rather than required member knowledge.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P35.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
