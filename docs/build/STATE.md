# Current build state

Updated October 24, 2026 (Asia/Manila).

- Current resumable step: **P05 — blocked_external**. Local invitation/schema/UI/security checks delivered; full Supabase/real Google/JWT verification pending. Resume with build-prompts/CONTINUE.md.
- Completed P00/P01. P02–P04 retain Docker/Supabase PostgreSQL 17, JWT/PostgREST, official-type and live Google blockers. P06–P63 not executed; P07 record scopes intentionally absent.
- Detailed checkpoint docs/build/steps/P05.md. Contracts docs/guests.md, docs/permissions.md, docs/integrations.md, docs/build/CONTRACTS.md, supabase/README.md; DESIGN.md remains visual authority.

## Delivered interfaces

12 public tables/154 columns/10 functions. P02 identity/P03 policies/P04 exact school roster admission remain. P05 adds guest_invitations and guest_invitation_events with forced RLS/no direct API grants. create_guest_invitation, redeem_guest_invitation, revoke_guest_access, list_guest_invitations derive actor/sponsor; hashed one-use tokens, exact verified email, default/max 14 days, version/retry safety, sponsor-only metadata and redacted transactional audit. Renewal invalidates old access.

resolve_auth_context wraps unchanged private core resolver with separate minimal guest context, no core membership/capabilities. Current sponsor authority, verified email, expiry/revocation rechecked. No guest member/term membership/role created. Invitations share **zero records** until P07 creates real scope FKs. No invented work IDs, full-directory fallback, email sending or OTP.

Sponsor /guests uses real RPCs, scope preview, copy/select fallback, renew/revoke. Public /guest/redeem removes fragment bearer; memory only, never browser storage/return path. Sign in via Google then reopen original invitation link. Guest core/admin direct links redirect to /shared; DB remains authoritative. Auth/navigation/focus/poll/expiry checks remain. No production fixture/preview bypass.

## Actual verification / blockers

Passed pnpm test:guests (three named assertions plus P04 on full P05); historical test:identity/test:authorization/test:google-auth; db:types/db:types:check; typecheck/lint/36 frontend tests/build. Browser verify-p05.cjs passed production unconfigured redemption (fragment removal, no request-URL bearer/storage, disabled setup actions, 320px) and labeled test-only simulated sponsor component (create/link/revoke, long email, 44px). verify-p04.cjs regression passed protected routing/callback/production preview exclusion. Evidence/screenshots docs/build/evidence/P05-*; P04 login captures refreshed.

These use isolated PGlite PostgreSQL 18.6/auth-shaped subjects and local browser checks, not Supabase PostgreSQL 17, real validated JWT/PostgREST or Google callback proof. Docker/Podman absent, .env.local/provider references unavailable and Google disabled (prior P04 observations carried forward). Official CLI types, real old-JWT revoke/expiry/sponsor-loss calls, external-account callback/consent, deployed log redaction and human UAT remain blocked. No remote reset or real records.

## Preview / custody

Live dev http://127.0.0.1:5173/preview and /guest/redeem, original session70434. Browser open requested (host queued); screenshots provide actual renders. Temporary production4173 stopped after checks. Sponsor screenshots explicitly label simulated gateway/fictional identity; no fixture endpoint ships.

User explicitly authorized GitHub backups. Existing public David-GY/TEDxAteneo2627 branch codex/core-build-checkpoints is configured as origin/upstream. P00–P04 commit0605c0f verified exact local/remote tree. P05 snapshot 8970e065f92eb22f4e17338f39a252a93bbe62a4 published on that branch; fetched remote tree 4612298a9d93181b3f24ae1eaed4f939ae0ec656 exactly equals local committed tree. Local branch aligned/tracking remote with a clean worktree. Signed-out gh CLI replaced by connected GitHub Git-data API. No PR/main merge, website/provider deployment or messages/invitations. Env/runtime/dependency/dist artifacts ignored.

## Next smallest action

Resume P05 with build-prompts/CONTINUE.md after local container runtime and approved Google/Supabase setup. Verify loopback target, migrate/seed synthetic DB, run guests/google SQL on Supabase17, compare official types, then real external PKCE and old guest-JWT requests before/after revoke/renew/expiry/sponsor suspension. Verify no raw-token request/DB logging. Carry P02–P04 gates forward. P06 only next separately requestable code-dependency-eligible prompt; do not auto-run or add P07 scopes here.

Real roster/FIN/MCD authority, guest sponsor policy, privacy custodian/basis/retention, production HTTPS origin, approved logo and human UAT remain open.

## Usage

P05 shared-account observations 56 → 64 → 66 → 71 → 74 usedPercent, reset1792816155. Effective allowance34 points, wind down85 usedPercent. Includes GitHub preservation/rechecks/shared activity, not exact attribution. No reset/credit purchase/waiting, agents, extra chats/worktrees. Node24.22.1/pnpm11.25.0; existing versions/lockfile preserved.
