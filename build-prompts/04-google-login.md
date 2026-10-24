# P04 — Connect Google login and protected routes

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P04: Connect Google login and protected routes.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F01; section 10 identity.
Code/interface prerequisites: P01, P03. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/auth/*; src/lib/supabase.ts; src/app/router.tsx; supabase/functions or auth hooks; docs/integrations.md

Interfaces / invariants:
Authenticated session resolves to an active member/term context; routes never infer organization access from email alone.

Implement and verify this bounded slice:
1. Implement Supabase Google PKCE callback, exact redirect allowlist configuration, account switching/sign-out, and roster validation through trusted server/database logic.
2. Enforce exact student.ateneo.edu plus roster for ordinary core entry, not suffix tricks or hosted-domain hints. Reserve explicit guest path for P05.
3. Handle unavailable config, rejected school OAuth, expired sessions and safe post-login return routes. Document provider setup using secret references, not credentials in source.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P04_A1: Approved school member enters; a different school student and lookalike domain do not.
- P04_A2: Expired/suspended membership cannot bypass by opening a route or using an old token.
- P04_A3: Real Google callback tested if credentials exist; otherwise local authorization tests pass and live OAuth verification is explicitly blocked, not claimed complete.

Update docs/build/steps/P04.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
