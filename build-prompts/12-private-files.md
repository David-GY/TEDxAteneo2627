# P12 — Implement private uploads, Drive links and immutable manifests

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P12: Implement private uploads, Drive links and immutable manifests.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F07/F23; section 11 file controls.
Code/interface prerequisites: P07, P11. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/files/*; supabase/functions/files/*; supabase/migrations/*assets.sql; supabase/tests/files.test.sql

Interfaces / invariants:
assets and asset_links with classification, hash, size and source; finalize_upload creates immutable manifest; downloads reauthorize and audit.

Implement and verify this bounded slice:
1. Implement private PDF/JPEG/PNG uploads with proposed 5MB/file and 20MB/submission limits, content validation, random paths and safe download behavior.
2. Add validated Drive/Docs/Sheets/Slides/Canva working links with access notes. A working URL is not approved evidence; support snapshot hashes/versions.
3. Inherit effective record access for file operations, prevent widening through extra links, and record restricted downloads without logging contents/tokens.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P12_A1: Anonymous/other-unit/revoked user cannot download object via direct path or issue a signed URL.
- P12_A2: MIME mismatch, executable/SVG/HTML/archive and oversize files are rejected.
- P12_A3: Replacing a working source does not overwrite a finalized snapshot; hashes and manifest stay stable.

Update docs/build/steps/P12.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
