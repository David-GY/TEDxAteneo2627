# P52 — Export selected final evidence safely between app and Drive

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P52: Export selected final evidence safely between app and Drive.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F23/F10/F24; section 10 Drive custody.
Code/interface prerequisites: P51, P28, P46, P47. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/drive/exports/*; supabase/functions/drive-export/*; docs/drive-custody.md

Interfaces / invariants:
User-triggered rendition/export creates new immutable app asset/Drive copy with manifest and destination classification; source and approved snapshot stay distinct.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD03, AD05.
- Explain which final revision/copy goes to which approved destination in plain language; show readable filename/ref and progress before/after export. Keep original/approved snapshot distinct and technical manifest details scoped.
- Use resumable error/retry and duplicate prevention; no provider-folder code entry for normal selection and no broad sensitive mirroring.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Export explicitly selected Google-native final rendition into private app evidence, hashing bytes and binding caption/use in the submitted revision.
2. Implement authorized selected-file/data copy into approved Drive folder with current destination-permission check and audit. Separate FIN/PRISM destinations; no membership-wide sensitive mirroring.
3. Add resumable progress/error handling and duplicate-copy prevention; preserve originals until a verified archival disposition.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P52_A1: Changed Drive/Canva source cannot rewrite approved app snapshot or retained decision hash.
- P52_A2: Private FIN/PRISM file cannot be copied into broader folder without explicit authorized reclassification/policy; deny unsafe destination.
- P52_A3: Retry does not create endless duplicate files; revoked destination access yields clear recoverable failure.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P52_U1: A user can distinguish original working file from submitted immutable copy and recover an interrupted export without duplicate files or rewritten approvals.
- P52_U2: Renamed source/destination/ref labels preserve bindings; lost or overly broad destination access fails with a safe repair path and no private payload leak.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P52.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
