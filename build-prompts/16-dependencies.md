# P16 — Enforce task dependencies and meaningful blocked states

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P16: Enforce task dependencies and meaningful blocked states.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F05/F03; section 8 task_dependencies.
Code/interface prerequisites: P15. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/tasks/Dependencies.tsx; supabase/migrations/*dependencies.sql; supabase/tests/dependencies.test.sql

Interfaces / invariants:
add_task_dependency and remove_task_dependency enforce finish-to-start/informational types, no cycles and required dependency readiness.

Implement and verify this bounded slice:
1. Add dependency schema and commands with authorization on both records and no metadata leaks. Serialize graph edits sufficiently to prevent concurrent cycle creation.
2. Expose blocker/next-step information in task and contribution views; distinguish informational links from required gates.
3. Handle cancelled predecessors and explicit scope exceptions with reasons without waiving FIN/MCD rules.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P16_A1: Self-edge, A→B→A cycle and concurrent inverse edges cannot corrupt graph.
- P16_A2: Required unfinished predecessor blocks readiness; informational link does not.
- P16_A3: Restricted predecessor shows only permitted neutral information and no private title/count leak.

Update docs/build/steps/P16.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
