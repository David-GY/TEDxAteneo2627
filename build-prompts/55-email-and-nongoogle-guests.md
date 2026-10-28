# P55 — Add a verified email sender and optional non-Google guest login

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P55: Add a verified email sender and optional non-Google guest login.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F01/F19; section 10 email/SMTP.
Code/interface prerequisites: P05, P41, P46, P49. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/email/*; supabase/functions/email-adapter/*; src/features/auth/*; docs/email-operations.md

Interfaces / invariants:
Approved sender with tested quota/domain and server-only credentials; optional guest OTP identity must still redeem exact invite and scope.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD04, AD05, AD06.
- Give guests one clear current entry route with exact-invite/expiry/wrong-account help and safe return; do not require understanding SMTP, tokens or identity-link internals.
- Keep provider-unavailable entry/fallback honest and optional; no activation on untested sender and no guest connection/setup burden for unrelated work.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Connect existing approved free/organization sender only; implement minimal digest/transactional adapter with rate caps, dedup, retry and delivery health. No assumed Supabase default SMTP production service.
2. If provider delivery is verified, add email OTP/magic-link guest entry with verified address, single-use exact invitation and safe return URL. Do not activate it on an untested sender.
3. Handle bounce/quota/revocation and identity-linking/account-takeover risks; leave in-app/Google/manual invite link fallback working.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P55_A1: Wrong email/expired invite/OTP replay cannot gain guest access; unverified email cannot link to existing school member.
- P55_A2: Sensitive email is generic with authenticated link and never contains receipt/feedback text.
- P55_A3: Missing sender/DNS/quota blocks external verification and activation rather than returning fake sent messages.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P55_U1: A guest can recognize expired/wrong-account/undelivered entry and use a permitted recovery route without leaking invite existence or taking over a school identity.
- P55_U2: Missing sender/quota keeps activation visibly blocked, not Sent; safe retry cannot redeem an invite twice or expose private mail contents.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P55.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
