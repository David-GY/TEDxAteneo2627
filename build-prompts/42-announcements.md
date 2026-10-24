# P42 — Publish scoped announcements and acknowledgments

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P42: Publish scoped announcements and acknowledgments.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F18; section 3 publishing.
Code/interface prerequisites: P41, P32. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/announcements/*; supabase/migrations/*announcements.sql; supabase/tests/announcements.test.sql

Interfaces / invariants:
Published announcement has audience, immutable revisions, pin/expiry, publisher and acknowledgments against material revision.

Implement and verify this bounded slice:
1. Build draft/publish/edit/pin/expire and core/committee audience selection for authorized publishers.
2. Add acknowledgment and material-edit renewed acknowledgment without treating it as a legal waiver.
3. Wire overview/inbox and private file visibility. Guests need explicit share; resource-draft ability is not announcement publisher authority.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P42_A1: Other committee/guest cannot enumerate unshared announcement contents or counts.
- P42_A2: Materially edited announcement does not reuse prior acknowledgment silently.
- P42_A3: Narrower attachment remains restricted even when announcement audience is wider.

Update docs/build/steps/P42.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
