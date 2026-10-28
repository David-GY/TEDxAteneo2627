# P57 — Build room intake, Logistics confirmation and calendar views

**Select before sending:** GPT-6.1 Sol · Medium

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P57: Build room intake, Logistics confirmation and calendar views.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F11/F12; section 7 room flow.
Code/interface prerequisites: P56. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/rooms/*; src/features/calendar/*; src/features/requests/*

Interfaces / invariants:
Room UI uses P56 commands, showing desired vs confirmed slot, evidence and conflict/alternative negotiation.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD02, AD04, AD05, AD09.
- Build one room-request journey with named room/requirements, readable alternatives and explicit desired versus official confirmed slot. Reuse requester Back/Change/Review and current owner/contact patterns.
- Preserve safe entries on stale availability/conflict; show the permitted next response and clear cancelled/confirmed details on mobile/keyboard without a separate generic control console.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Build accessible room/time/requirements request, Logistics availability/conflict view and alternative-slot acceptance.
2. Add official reference/evidence, confirmed/cancelled details and linked calendar entry. Initial recurring sessions are separate explicit instances.
3. Handle stale availability and concurrent-conflict response without false confirmation or losing requester's safe input.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P57_A1: Mobile/keyboard requester can submit and distinguish pending from confirmed.
- P57_A2: Change/cancel updates actual reservation/calendar without stale duplicates.
- P57_A3: Unauthorized role cannot confirm, and private meeting details remain scoped despite room availability display.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P57_U1: A requester can choose an alternative after conflict without reentering safe information or mistaking a held/requested slot for confirmed.
- P57_U2: Named action/confirmation,44px mobile controls and keyboard operation retain private-meeting boundaries and idempotent calendar updates.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P57.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
