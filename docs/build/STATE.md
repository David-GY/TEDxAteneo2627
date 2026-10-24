# Current build state

Updated October24,2026 (Asia/Manila).

- Current step: **P06 — blocked_external**. Local directory/profile/contact scope delivered and verified. Not marked complete: real provider and human acceptance remain open.
- Complete: P00/P01. P02–P05 remain blocked_external with their exact ledgers preserved. P07–P63 not executed.
- Next external action: supply approved local Supabase17/container and Google setup, then resume P06 via build-prompts/CONTINUE.md for real JWT/PostgREST/provider/human checks. **P07 (build-prompts/07-work-record-spine.md) is the next separately requestable code-dependency-eligible prompt**, not auto-executed.
- Contracts: docs/people.md, docs/build/CONTRACTS.md, docs/permissions.md, docs/guests.md. Full history/checks: docs/build/steps/P06.md. DESIGN.md remains visual authority.

## Delivered interfaces

15 public tables/181 columns/17 functions, migrations001–009. P02 identity/P03 policies/P04 verified school roster/P05 invitation authority retained. P06 adds directory/process-contact projections; own core read and separate version/idempotency/audited private-value and visibility commands; optional skills/pronunciation/term affiliation disclosure; captured event actor-name attribution; guest own contact read/edit with invitation-bound authority. All new sensitive tables forceRLS and deny direct API grants. Private-profile and affiliation direct client writes are now revoked.

/people: one person across multiple units/current roles; name/unit/role search; exact-school organization contact; independently consent-filtered optional fields; plain primary/backup contacts, explicit missing assignments. /account: own core editor with separate save/sharing actions, all fields optional, blank affiliation never gates help/work links. MEAn grants no authority. Guest /account: own name/verified email/contact route only, optional own edit, empty shared-contact list; no full directory or core profile controls. No private browser storage, invented contacts, fixtures in production or fake save RPCs.

P05 zero-record sharing remains: guest contact attachment waits for P07 real scopes/FKs. No implicit sponsor-private-contact share or dangling work IDs. Historical P06 events retain captured actor labels after rename/suspension without querying old private profiles; no arbitrary historical-person lookup is exposed. New P07 record types must preserve their own attribution when implemented.

## Verification / exact limitations

PASS pnpm test:directory:3 named P06_A assertions plus3 guest-contact assertions on isolated PGlite18.6/auth-shaped subjects. Consent/head isolation, MEAn neutrality, blank affiliation, trim/clear/type/length validation, first insert, stale versions, retry conflicts, delayed retry/withdrawal, redacted transactional audit, frozen-term denial, retained attribution, guest own-only/no raw-grant access, wrong term/user, sponsor loss/expiry/revoke and anonymous denial covered.

PASS type generation/check15/181/17; typecheck/lint; full12files/46frontend tests; build156modules (app358.13kB/gzip111.12kB). PASS P05/P04 SQL regression on full current schema. PASS verify-p06.cjs labeled synthetic gateway desktop/320px directory/core editor/guest own contacts, separate saves, missing backup, optional skills/blank affiliation, no private storage/runtime errors. Captures inspected/shown. Detector[]; diff whitespace corrected and rechecked. Earlier checks/failures remain in P06 ledger.

P02–P05 blockers carried forward: Docker/Podman and real Supabase PostgreSQL17/Auth/PostgREST; official CLI types; real school/external Google PKCE/consent/callback; validated old guest-JWT revoke/renew/expiry/sponsor-loss API calls; deployed raw-token/body/parameter log redaction; human UAT. Actual multi-session concurrency remains unverified. Rechecked: Docker/Podman commands unavailable, .env.local absent, Google disabled in supabase/config.toml. No target/provider configuration changed, remote reset or service-role substitute.

Approved roster/primary-backup assignments, FIN/MCD authority, sponsor policy, privacy custodian/basis/retention, HTTPS origin, approved logo and human UAT remain open. P06 local tests do not establish live activation or satisfy later task/onboarding module UAT.

## Preview / custody / usage

Dev http://127.0.0.1:5173/preview restarted/retained (session68785); Codex browser requested. Actual core/guest renders shown using committed, clearly labeled fictional test-only fixture PNGs. No fixture endpoint ships. No website/provider deployment, messages/invitations, PR/main merge, agents, extra chats/worktrees or dependency changes.

User authorized reviewed commits/pushes to public David-GY/TEDxAteneo2627 branch codex/core-build-checkpoints. Prior snapshots29855b2/ad52536 fetched/tree-verified. Final P06 optional disclosure/guest-contact checkpoint is committed/pushed/fetched and exact local/remote tree checked after writing this ledger; hash reported in chat. Worktree checked before finish.

This execution shared observations93 →96 →97 →99% in reset1792816155 window; the window automatically rolled over to1 →7% with reset1792834180. User explicitly said continue until no credits, overriding headroom; no reset credit/purchase/wait used and no fresh40-point allocation claimed. Readings are shared-account observations, not exact task attribution. Stop reason is remaining external gates/P06 scope, not an invented credit exhaustion. See P06 ledger for historical earlier baselines.
