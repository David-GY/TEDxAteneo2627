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

Implement and verify this bounded slice:
1. Implement explicit Connect Drive consent separate from login, approved redirect/state checks and provider-owner custody. No all-drive crawling.
2. Add Picker-based selected files for authorized work, validating provider IDs, current record permission and selected file access.
3. Handle school admin denial, revoked scopes and testing-mode token expiry; retain working link/private upload fallback.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P51_A1: Client receives no refresh token/client secret and cannot nominate arbitrary unselected Drive files for broad reads.
- P51_A2: Different dashboard member cannot use connection to bypass their record/file access.
- P51_A3: Real selected-file flow verified if school/provider setup exists; otherwise adapter code/local tests marked external-blocked, not fully integrated.

Update docs/build/steps/P51.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
