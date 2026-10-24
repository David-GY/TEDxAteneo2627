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

Implement and verify this bounded slice:
1. Support roster/tasks import templates, row-level error report, deduplication, dry-run and confirmation of exact mapped changes.
2. Do not turn role columns or imported identity fields into unreviewed privileges; sensitive financial imports use separate authorized template/reconciliation.
3. Export permitted operations with stable IDs and neutralize spreadsheet formula prefixes; preserve dates/UTF-8/newlines correctly. No bidirectional Sheets sync.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P45_A1: Repeated import does not duplicate records and partial errors are reported consistently with chosen atomicity.
- P45_A2: CSV containing =,+,-,@ formula payloads cannot execute when opened in a spreadsheet as exported user content.
- P45_A3: Unauthorized export/import changes fail; role field cannot grant admin and unrelated private rows never appear.

Update docs/build/steps/P45.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
