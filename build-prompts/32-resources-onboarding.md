# P32 — Publish guides, glossary and an inclusive onboarding hub

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P32: Publish guides, glossary and an inclusive onboarding hub.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F14/F13; section 12 rollout.
Code/interface prerequisites: P31, P06. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/resources/*; src/features/onboarding/*; supabase/migrations/*resources.sql

Interfaces / invariants:
Versioned resources/glossary and onboarding_progress use owner/review dates, visibility, checklist version and stable term aliases.

Implement and verify this bounded slice:
1. Build Start Here checklist, contextual acronym explanations, service/process guides, who's-who links and practice sandbox task/request.
2. Provide head/publisher authoring with drafts, safe content, review reminders, ownership and published version. Treat MEA expansion as unconfirmed until supplied.
3. Allow skipped optional tours, late joiners and incomplete-task empty states; all core backgrounds receive equal guidance.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P32_A1: A member with no affiliation/course disclosure can complete essential onboarding.
- P32_A2: Renamed glossary label retains old alias and links without breaking forms.
- P32_A3: Restricted resource/file does not become public through guide links or preview; sandbox never submits a real FIN case.

Update docs/build/steps/P32.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
