# P51 — Connect scoped Google Drive selection

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P51: Connect scoped Google Drive selection.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F23; section 10 Drive levels.
Code/interface prerequisites: P49, P45, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/drive/*; supabase/functions/google-oauth/*; docs/integrations.md

Interfaces / invariants:
Separate Drive OAuth connection and Picker use drive.file or least necessary scope; server-only refresh-token storage, revoke/reconnect and selected-file metadata.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD05, AD06.
- Keep Connect Drive optional and distinct from sign-in; explain selected-file access and revocation plainly. Preserve usable link/private-upload fallback and no setup nags/blank navigation while disabled.
- Use readable filenames/owners and recoverable consent/denied/expired states; member work does not require provider IDs or a connection just to continue unrelated tasks.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Implement explicit Connect Drive consent separate from login, approved redirect/state checks and provider-owner custody. No all-drive crawling.
2. Add Picker-based selected files for authorized work, validating provider IDs, current record permission and selected file access.
3. Handle school admin denial, revoked scopes and testing-mode token expiry; retain working link/private upload fallback.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P51_A1: Client receives no refresh token/client secret and cannot nominate arbitrary unselected Drive files for broad reads.
- P51_A2: Different dashboard member cannot use connection to bypass their record/file access.
- P51_A3: Real selected-file flow verified if school/provider setup exists; otherwise adapter code/local tests marked external-blocked, not fully integrated.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P51_U1: Declining/revoking/losing Drive consent leaves essential work and the fallback usable without broadening another member file access.
- P51_U2: A genuine configured selected-file flow uses named controls and safe retry, with provider-denied behavior recorded honestly; no connection state is falsely shown successful.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P51.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
