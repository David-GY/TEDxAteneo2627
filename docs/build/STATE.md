# Current build state

Updated October 24, 2026 (Asia/Manila).

- Last executed/current resumable step: **P04 — blocked_external**. Local Google PKCE/protected-route/trusted admission code and checks pass; real provider/full Supabase checks pending.
- Completed: P00, P01. P02/P03 retain missing-runtime/PostgreSQL 17/JWT/PostgREST/official-type blockers. P05–P63 not executed.
- Checkpoint docs/build/steps/P04.md; resume with build-prompts/CONTINUE.md. Prior checkpoints remain evidence for their historical boundaries.
- Contracts: docs/integrations.md, docs/permissions.md, docs/build/CONTRACTS.md, supabase/README.md; DESIGN.md for shell.

## Current interfaces

Ten identity tables remain; P03 column/RLS restrictions and scoped helpers remain. P04 tightens current_term_membership to confirmed canonical school email, matching provider-managed verified Google identity, exact student.ateneo.edu domain and active current core roster. All inherited policies use that gate. Guests remain denied until explicit P05 invitation work; no guest creation or role self-grants.

Authenticated-only resolve_auth_context() derives auth.uid, locks/rechecks one preapproved roster row, links only unlinked/same-UID identity and activates invited account only with active core term membership. Returns safe denied or member/organization/term/membership/expiry/capabilities context. No actor/email inputs, metadata-based grants or automatic roster/role creation. Private school verifier is not exposed. Public catalog types cover six helpers, ten tables/133 columns.

Frontend uses pinned Supabase JS 2.118.0, dynamically loaded for configured/approved origins; PKCE/manual callback exchange, getUser + database resolution, protected parent loader on navigation, auth/focus/visibility/poll/end-time revalidation, account switch and browser-local sign-out. Exact redirect/return allowlists; sanitized callback diagnostics, no-referrer. No business data or fake success actions. No config shows login Setup needed. Only development has /preview; production preview path is absent.

## Actual verification

Passed test:google-auth (three named local SQL assertions), historical test:authorization/P03 and test:identity/P02, db:types / db:types:check, typecheck, lint, test (31 tests), build. Actual production browser smoke passed: protected deep-link redirect, no production preview bypass, rejected callback details removed/recovery, 320px reflow, zero runtime errors/external requests. JSON/hash/screenshot evidence under docs/build/evidence/P04-*.

No live provider proof: .env.local absent; expected Google client-ID/secret environment references false; Google disabled by default. Supabase status fails missing Docker/Podman; local P04 SQL command fails ECONNREFUSED 127.0.0.1:54322. Embedded PostgreSQL 18.6/PGlite uses minimal auth fixtures, not configured Supabase PostgreSQL 17 or real validated JWTs. No actual Google callback, full Supabase migration/API/official type result claimed. Historical P02/P03 SQL suites must not run unmodified against the tightened current schema; scripts preserve their migration boundaries.

## Preview / connections

User preference: always show a preview while working. Live development shell http://127.0.0.1:5173/preview; login http://127.0.0.1:5173/login. Original dev session 70434 retained; restart pnpm dev if ended (strict port, avoid duplicates). Browser open requested, host queued; captured current login/mobile/shell previews. Production 4173 served temporarily for smoke and stopped afterward. P01 browser harness describes its older public-shell boundary; use verify-p04.cjs for current production routes.

No linked remote project, credentials, provider session/configuration changes, real records or external deployment. SQL checks use isolated in-memory DB; CLI test explicitly loopback only.

## Next smallest action

Resume P04 with build-prompts/CONTINUE.md after local runtime and approved Google/Supabase setup. Follow docs/integrations.md for secret references, exact callback origins/URLs, provider enablement and verified local target. Run P04 SQL on Supabase 17, compare official types, then real school Google callback/PKCE/negative identities/old-token expiry-suspension/account switch/sign-out and JWT/REST checks. Never use remote reset or service-role principal as a substitute. P02/P03 blockers remain live activation gates.

P05 is next code-dependency-eligible only if separately requested, carrying these exact blockers; do not auto-run. Production HTTPS origin still needs approval/configuration. Real roster/FIN/MCD authorities, school policy, privacy custodian/basis/retention, audit/privileged workflows, logo and human UAT remain future gates.

## Usage/custody

P04 shared-account five-hour observations 45 → 49 → 53 usedPercent, reset 1792816155; observed +8 within 40-point soft allowance, not exact task attribution. P03 37 → 40 → 42; P02 29 → 33 → 35. No reset purchase/waiting. No agents/chats, branches/worktrees, messages/invitations, commits/push, provider changes or deployment. Node 24.22.1 / pnpm 11.25.0 / TS 6.0.3, one lockfile. Original plan/prompt pack preserved.
