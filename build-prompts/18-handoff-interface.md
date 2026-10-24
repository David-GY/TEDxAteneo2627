# P18 — Build incoming and outgoing handoff actions

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P18: Build incoming and outgoing handoff actions.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F06/F02; section 4 Working Together.
Code/interface prerequisites: P17, P13. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/handoffs/*; src/features/overview/*; src/features/synergies/*

Interfaces / invariants:
Screens consume immutable package/receipt and P17 transitions; overview gains authorized incoming handoffs and sender revision actions.

Implement and verify this bounded slice:
1. Add package submission, file/criteria preview, accept/request-changes/decline/withdraw actions and readable history.
2. Show who currently owes the next action, proposed date and explicit acceptance state in Working Together/task detail.
3. Connect accepted next work to both committee views without changing accountability or granting unrelated records.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P18_A1: Receiver can review package on mobile/keyboard and understands changes requested versus accepted.
- P18_A2: Sender cannot mark own package accepted by editing UI state or replaying endpoint.
- P18_A3: Overview deduplicates handoff/task events and removes resolved actions after refresh.

Update docs/build/steps/P18.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
