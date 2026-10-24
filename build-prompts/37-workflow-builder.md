# P37 — Build the bounded workflow and approval editor

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P37: Build the bounded workflow and approval editor.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22; section 6 workflow engine.
Code/interface prerequisites: P36, P22. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/workflows/*; supabase/tests/workflow_publication.test.sql

Interfaces / invariants:
Workflow editor emits P22-compatible sequential stable stages, one/all eligible reviewers, revision routes and bounded conditions; publication uses P35.

Implement and verify this bounded slice:
1. Implement stage ordering, reviewer/role/scope resolution, required evidence, decision routes, authorized delegates and reminder settings.
2. Preview synthetic cases including requester conflict and missing authority; show open cases pinned to previous versions.
3. Reject unbounded loops, unsafe scripts, nonexistent approvers and configurations bypassing FIN/MCD protected policy. No generic BPM product.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P37_A1: Head can configure a service review without editing source code.
- P37_A2: Removing a required financial/creative authority or assigning only requester as reviewer fails publication.
- P37_A3: New version applies to new instances; an active old case continues or explicitly migrates with audited authority.

Update docs/build/steps/P37.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
