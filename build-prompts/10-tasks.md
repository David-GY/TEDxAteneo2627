# P10 — Implement task creation, assignment and progress

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P10: Implement task creation, assignment and progress.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F05/F07; section 3 task permissions.
Code/interface prerequisites: P09. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/tasks/*; supabase/migrations/*tasks.sql; supabase/tests/tasks.test.sql

Interfaces / invariants:
create_task, update_task, assign_task and transition_task; tasks relate to one canonical work item and optional deliverable/contribution.

Implement and verify this bounded slice:
1. Implement My Tasks and task detail/editor with checklist, assignee, collaborators, dates, blocked reason and typed status categories.
2. Enforce own/unit/shared editing and prevent cross-unit assignment until accepted agreement exists. Preserve expected-version conflicts and original dates.
3. Treat Done as completion evidence/review appropriate to task type, never as authority to approve financial/publicity work.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P10_A1: Duplicate retry creates one task; unauthorized assignee/owner changes fail.
- P10_A2: Different committee cannot receive an imposed task before agreement/head acceptance.
- P10_A3: Assignee can update allowed progress; overdue/date-only behavior is correct in Manila.

Update docs/build/steps/P10.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
