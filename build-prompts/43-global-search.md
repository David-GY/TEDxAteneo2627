# P43 — Implement permission-filtered keyword search

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P43: Implement permission-filtered keyword search.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F20; section 3 search rules.
Code/interface prerequisites: P42, P33. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/search/*; supabase/migrations/*search.sql; supabase/tests/search_access.test.sql

Interfaces / invariants:
search_workspace(query, filters, cursor) applies authorization before snippets/counts across operational titles/IDs, guides and allowed contacts.

Implement and verify this bounded slice:
1. Add suitable PostgreSQL full-text/trigram indexes and exact term-aware tracking lookup; support renamed-unit aliases.
2. Build categorized accessible results, empty/error states and safe restricted-result behavior.
3. Exclude finance raw payload, evaluations, private profile fields and attachment extraction from global index. No external AI search.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P43_A1: Searching a known private title/amount/contact or restricted ID reveals no existence/count/snippet.
- P43_A2: Exact ID distinguishes terms and maps renamed unit aliases without collisions.
- P43_A3: Typeahead/keyboard/mobile behavior works; SQL parameters and pagination cannot widen scope.

Update docs/build/steps/P43.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
