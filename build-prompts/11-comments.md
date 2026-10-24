# P11 — Add comments, history and eligible mentions

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P11: Add comments, history and eligible mentions.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F07; section 3 inherited access.
Code/interface prerequisites: P10. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/comments/*; supabase/migrations/*comments.sql; supabase/tests/comments.test.sql

Interfaces / invariants:
add_comment and revise_comment preserve author/edit history; mention candidates come from eligible participants only.

Implement and verify this bounded slice:
1. Build plain-text or safely sanitized Markdown comments shared by task/deliverable records. Show author, timestamps, edits and current permission state.
2. Retain original comment revisions referenced in submissions or decisions. Implement own draft removal and reasoned redaction rather than deleting evidence history.
3. Emit outbox mention events without sending external messages. Do not expose private directory candidates through autocomplete.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P11_A1: Script/HTML payload does not execute; pasted unsafe links do not become executable content.
- P11_A2: Unrelated user cannot enumerate comments, revisions or mention candidates.
- P11_A3: Editing a decision-referenced comment preserves original evidence and shows later amendment.

Update docs/build/steps/P11.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
