# P05 — Add scoped off-domain guest invitations

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P05: Add scoped off-domain guest invitations.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F01; section 3 guest rules.
Code/interface prerequisites: P04. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/guests/*; supabase/migrations/*guests.sql; supabase/tests/guests.test.sql

Interfaces / invariants:
create_guest_invitation, redeem_guest_invitation, revoke_guest_access use hashed one-time tokens, verified identity, sponsor, exact record scopes and expiry.

Implement and verify this bounded slice:
1. Implement invitation storage and server commands with exact verified-email binding, default 14-day access, single-use redemption and audit. Record-scoped targets attach once P07 exists.
2. Build sponsor admin form with clear scope preview, copy-link action, expiry/renew/revoke. External Google accounts work; no automatic email sending.
3. Ensure current DB checks revoke existing sessions' data access. Keep invitation model provider independent; do not add untested non-Google OTP.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P05_A1: Forwarded token cannot be used by another email; double redemption and expired tokens fail.
- P05_A2: Off-domain guest receives no full directory or membership-wide scope by default.
- P05_A3: Revocation is enforced with a previously issued JWT, and no raw invite token is stored or logged.

Update docs/build/steps/P05.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
