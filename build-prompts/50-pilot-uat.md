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

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD02, AD03, AD04, AD05, AD06, AD07, AD08, AD09.
- Use the original representative first-time/experienced/guest/head cohort and intended scopes. Observe finding-specific journeys: first work/owner/date/action within two minutes after basic orientation, contact discovery, correct service selection, short-ref use, review versus submission, safe retry and optional disclosure/tour behavior.
- Record actual per-task success/time/wrong turns/help, environment/revision and defects; target at least90%essential assigned flows unassisted after onboarding as the original proposed project threshold. Repair essential/high-impact friction before optional expansion; research affiliation groups are optional/consented and never product eligibility.
- Close each AD finding only with implementation plus its observed/automated evidence as appropriate; give unresolved findings owner/impact/next action. Missing participants/provider setup keeps human acceptance pending, not simulated green.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Exercise school member/head/FIN/MCD/guest flows: deliverable -> synergy -> task/dependency -> handoff -> versioned reviews -> acceptance, including required denials.
2. Prepare role-specific UAT scripts for both MEAn and non-MEAn participants, first-task guidance, steward instructions, privacy gate and defect triage.
3. Fix supported P0/P1 implementation defects within this session budget. Human UAT needs actual user evidence; do not fabricate participants, feedback or approvals and do not send invitations/messages.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P50_A1: Core happy path and negative access/revision/self-approval cases pass with release revision recorded.
- P50_A2: Human results remain pending until observed; zero open P0/P1 is required for a green release gate.
- P50_A3: Actual restore, relevant school authority/privacy decisions and named custodians are verified or explicitly listed as blockers.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P50_U1: Actual newcomer records distinguish observed success from assisted/failed/not-run tasks; automation, login counts and guide checkboxes cannot satisfy the two-minute/90%human targets.
- P50_U2: Unresolved essential usability/accessibility failures cannot be waived by completing all feature prompts. A blank-affiliation late joiner and an off-domain scoped guest have appropriate work/help without learning internal codes.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P50.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
