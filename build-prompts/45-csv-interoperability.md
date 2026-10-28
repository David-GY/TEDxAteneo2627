# P45 — Add previewed Sheets-compatible CSV import and scoped export

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P45: Add previewed Sheets-compatible CSV import and scoped export.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F23/F13/F21; section 10 Sheets.
Code/interface prerequisites: P44, P33. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/imports/*; src/features/exports/*; supabase/functions/imports/*; src/features/imports/csv.test.ts

Interfaces / invariants:
Import preview/mapping/validation commits through authorized existing commands with stable IDs; export uses effective scope and spreadsheet-safe values.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD03, AD05, AD07.
- Provide a small example CSV template, named column mapping, readable row-specific repair messages and exact before/after confirmation. Ordinary task import uses known people/refs rather than requiring UUIDs or permission codes.
- Preserve old/issued short refs and UUID relationships across import/export. A resumable failed import retains mapping/input context safely and must not duplicate work or require manual numbering.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Support roster/tasks import templates, row-level error report, deduplication, dry-run and confirmation of exact mapped changes.
2. Do not turn role columns or imported identity fields into unreviewed privileges; sensitive financial imports use separate authorized template/reconciliation.
3. Export permitted operations with stable IDs and neutralize spreadsheet formula prefixes; preserve dates/UTF-8/newlines correctly. No bidirectional Sheets sync.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P45_A1: Repeated import does not duplicate records and partial errors are reported consistently with chosen atomicity.
- P45_A2: CSV containing =,+,-,@ formula payloads cannot execute when opened in a spreadsheet as exported user content.
- P45_A3: Unauthorized export/import changes fail; role field cannot grant admin and unrelated private rows never appear.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P45_U1: A malformed/duplicate row can be repaired and retried without duplicating a task, changing its issued ref, assigning implicit authority or losing the remaining review context.
- P45_U2: Export contains permitted title/ref/term context and safe spreadsheet values; unauthorized lookups/import mapping cannot disclose hidden roster or case details.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P45.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
