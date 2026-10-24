# P06 — Build the permitted member directory and process contacts

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P06: Build the permitted member directory and process contacts.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F13/F14; section 3 private data.
Code/interface prerequisites: P01, P04. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/people/*; src/features/account/*; supabase/tests/directory.test.sql

Interfaces / invariants:
Directory query returns safe name/unit/role/contact-route fields; private profile updates and visibility choices are separate commands.

Implement and verify this bounded slice:
1. Build searchable basic people/unit/contact views, own profile editor and optional affiliation/skills/course/contact fields with clear sharing controls.
2. Make process contacts primary/backup and display plain descriptions rather than requiring acronyms. Use synthetic units until official roster arrives.
3. Keep guest directory limited to own/shared contacts; names in past records remain attributable without granting access to old private profiles.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P06_A1: Head cannot change another member's optional disclosure or see unshared contact/course fields.
- P06_A2: Affiliation left blank does not block tasks/onboarding or remove help links.
- P06_A3: Multi-unit membership and missing backup contact render clearly on mobile without duplicate people.

Update docs/build/steps/P06.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
