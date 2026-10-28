# P54 — Add opt-in Telegram alerts without reading group chats

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Optional v2

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P54: Add opt-in Telegram alerts without reading group chats.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F19; section 10 Telegram.
Code/interface prerequisites: P41, P46, P49. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/telegram/*; supabase/functions/telegram-webhook/*; supabase/functions/notification-adapters/*

Interfaces / invariants:
One-time account-link code binds started bot chat to authenticated member; webhook secret validation and minimal outbox adapter.

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD02, AD05, AD06.
- Make opt-in link/unlink and failure/relink states understandable; Telegram remains a supplemental alert channel, never necessary to find authoritative work.
- Keep generic scoped deep links, digest/quiet-hour explanations and no disabled-module navigation or automatic account messaging.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Build opt-in link/unlink flow after member starts bot; hash short-lived binding code and prevent chat takeover/reuse.
2. Implement authenticated provider webhook handling and dispatch safe generic restricted alerts with deep links, quiet-hours/digest preferences and bounded retries.
3. Provide failure/relink status; no group-chat scraping, automatic personal-account messaging or unrequested announcements.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P54_A1: Stolen/expired/reused linking code cannot attach another member; invalid webhook source rejected.
- P54_A2: Revoked member or removed channel stops new deliveries and cannot open protected deep link.
- P54_A3: Repeated dispatch deduplicates logically and carries no private financial/evaluation contents.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P54_U1: Unlink/revocation stops delivery without hiding in-app pending work; failed/expired link codes have a clear safe restart and cannot bind another member.
- P54_U2: Retry cannot create duplicate logical alerts or leak restricted titles/content; no unrequested message is sent while testing the UI.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P54.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
