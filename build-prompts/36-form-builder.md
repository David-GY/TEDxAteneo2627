# P36 — Add readable work references and build the request form editor

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P36: Add readable work references and build the request form editor.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22; section 6 Form builder.
Also read docs/build/ADOPTION-DELIVERY.md, docs/work-items.md, docs/tasks.md and the existing request-submission contract discovered under docs for stable UUIDs, current creation commands and request tracking.
Code/interface prerequisites: P35, P20. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/forms/*; src/features/forms/*; supabase/tests/form_publication.test.sql

Interfaces / invariants:
Editor produces the same FormDefinition accepted by P20, preserving stable keys/options and routing confidential payloads correctly.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD03, AD05, AD07.
- Batch36-R1 before the form editor: implement the missing member-facing references for existing tasks and deliverables, using TASK-027 and DEL-012 as default display formats, with the term separate where needed. Keep UUID primary keys/deep links and existing FIN/MCD/general request IDs unchanged. Add a reviewed migration for server-only per-term/per-kind allocation and deterministic resumable backfill, serialized with new creation and existing idempotent commands; no UUID truncation, recycled sequence or mutation of issued IDs. Extend existing authorized list/detail selectors with display references, title-first labels and Copy reference/Copy link. Reference lookup must authorize before revealing existence; exact global search remains P43.
- Batch36-R2: build the original bounded form editor from useful templates with named field/section controls, readable confidentiality help and optional advanced conditions. Group longer requester forms into relevant steps with Back/Change/Review and safe in-memory input retention. Simple tasks/requests must not acquire irrelevant finance/provider/profile fields. Stable field/option keys stay internal and unchanged when labels move or rename.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Implement field/section add/edit/reorder/remove-draft, supported types, help, required conditions, options and repeatable lines with keyboard controls.
2. Add synthetic preview and schema validation; enforce limits and fixed operators. Reserved finance/approval values remain typed protected fields.
3. Publish through P35; show impact on drafts and explicit migration rather than changing submitted data. Explain why confidential fields need restricted storage/type.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P36_A1: Renaming a label does not change stored field key/old answer meaning.
- P36_A2: A confidential custom field cannot publish into broad ordinary JSON.
- P36_A3: Published old form submissions remain readable under their version; unsafe condition/code and excessive schema size fail.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P36_U1: Concurrent creation, identical retry and interrupted/resumed backfill produce one immutable reference per record and no duplicate qualified(term,kind,sequence) reference; numbering grows past999 without truncation. Renames/revisions preserve issued refs and old UUID links; existing request refs are byte-for-byte unchanged.
- P36_U2: Short reference never grants access: another unit/expired guest cannot resolve a hidden title/count/record by guessing a ref. Cross-term display/copy includes unambiguous term context; failed/unsaved creation is not falsely announced as issued.
- P36_U3: A representative short requester form can be completed without keys/codes or irrelevant sections; Back/validation/conflict preserves safe fields, conditional hidden values cannot bypass server rules, and published forms remain compatible with P20/P35 and historical submissions.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P36.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
