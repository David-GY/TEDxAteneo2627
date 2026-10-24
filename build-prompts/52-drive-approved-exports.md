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

Implement and verify this bounded slice:
1. Export explicitly selected Google-native final rendition into private app evidence, hashing bytes and binding caption/use in the submitted revision.
2. Implement authorized selected-file/data copy into approved Drive folder with current destination-permission check and audit. Separate FIN/PRISM destinations; no membership-wide sensitive mirroring.
3. Add resumable progress/error handling and duplicate-copy prevention; preserve originals until a verified archival disposition.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P52_A1: Changed Drive/Canva source cannot rewrite approved app snapshot or retained decision hash.
- P52_A2: Private FIN/PRISM file cannot be copied into broader folder without explicit authorized reclassification/policy; deny unsafe destination.
- P52_A3: Retry does not create endless duplicate files; revoked destination access yields clear recoverable failure.

Update docs/build/steps/P52.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
