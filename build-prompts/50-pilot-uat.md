# P50 — Run the core pilot release gate and prepare human UAT

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core gate

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P50: Run the core pilot release gate and prepare human UAT.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F01–F14 core subset/F19/F22–F26; sections 12/14.
Code/interface prerequisites: P49. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
tests/e2e/core-pilot.spec.ts; docs/uat/*; docs/build/release-gate.md; feature fixes as justified

Interfaces / invariants:
Reproducible synthetic core slice and a human-test checklist with separate observed/automated/human-pending results.

Implement and verify this bounded slice:
1. Exercise school member/head/FIN/MCD/guest flows: deliverable -> synergy -> task/dependency -> handoff -> versioned reviews -> acceptance, including required denials.
2. Prepare role-specific UAT scripts for both MEAn and non-MEAn participants, first-task guidance, steward instructions, privacy gate and defect triage.
3. Fix supported P0/P1 implementation defects within this session budget. Human UAT needs actual user evidence; do not fabricate participants, feedback or approvals and do not send invitations/messages.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P50_A1: Core happy path and negative access/revision/self-approval cases pass with release revision recorded.
- P50_A2: Human results remain pending until observed; zero open P0/P1 is required for a green release gate.
- P50_A3: Actual restore, relevant school authority/privacy decisions and named custodians are verified or explicitly listed as blockers.

Update docs/build/steps/P50.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
