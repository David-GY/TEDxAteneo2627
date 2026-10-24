# Current build state

Updated October24,2026 (Asia/Manila).

- Current step: **P07 — blocked_external**. Local work spine/grants/commands/audit/outbox implementation and named acceptance delivered; real Supabase17/JWT/PostgREST/parallel-session and human/provider checks pending.
- Complete: P00/P01. P02–P06 remain blocked_external with exact ledgers preserved. P08–P63 not executed.
- Resume P07 via build-prompts/CONTINUE.md after approved provider/runtime prerequisites. Next separately requestable code-dependency-eligible prompt: **P08 — build-prompts/08-deliverables-reading.md**; do not auto-run.
- Contracts: docs/work-items.md (P07), docs/build/CONTRACTS.md, docs/permissions.md, docs/guests.md, docs/people.md. Detail/evidence/blockers: docs/build/steps/P07.md. DESIGN.md remains visual authority.

## Delivered interfaces

25public tables/306columns/25functions, migrations001–010. P07 adds work_items, fixed deliverables/tasks/requests/announcements children, record_grants, status_definitions, immutable audit_events/idempotency_keys and private pending outbox_jobs. Same-term/kind FKs, deferred exactly-one-child, immutable child identity/status semantic/original due/history and actor/time/version stamps. Expected version is work_items.version; child stamps track body edits. No generic EAV platform, approval/status/owner transition, external job worker or later work UI.

Ordinary core sees safe summary columns; exact participants see child bodies/audit; restricted titles/parent IDs/siblings remain hidden. read_work_parent checks both records independently. Work-scoped role FKs never expand to unit/term authority. Explicit member/unit/guest invitation grant FKs/current authority rechecked; guests read-only, no core directory/profile. New/renewed invitations start empty; sponsor counts/redemption and safe shared organization contacts now derive from actual record grants, no implicit parent/sibling or sponsor-private-contact sharing.

create_work_item/update_work_item/grant_work_access/revoke_work_access derive actor, validate bounded draft inputs, check expected versions, serialize key/work changes and atomically persist earlier receipt/redacted audit/pending outbox. Retry exact prior result; changed payload conflict; UTC-normalized expiry key; current access checked before cached result. Direct client mutations denied. src/lib/commands.ts exposes4 typed adapters and sanitized discriminated errors, no automatic retry/fake success. Retained names avoid private historical-profile joins.

P06 core profiles/optional sharing, blank-affiliation/MEAn neutrality and guest own-contact editor remain. P05 exact verified-email/token/sponsor/expiry/revoke boundary remains; actual P07 record sharing extends its former zero-record-only scope. No production fixture/auth bypass or real records.

## Actual verification / exact gates

PASS pnpm test:work-access3 named P07_A assertions: child/grant/parent/sibling/detail isolation, same-term/type integrity, role/unit/guest/current subject gates, exact prior receipt/canonical retry conflict, two-actor sequential stale-version rejection, denied/forced-outbox rollback, redacted audit/outbox and retained labels. **Not actual parallel-session Supabase proof.** PGlite18.6/auth-shaped subjects only.

PASS P05/P04 and P06 SQL regressions on full P07 schema; generated/check types25/306/25; typecheck/lint;54frontend tests in13files; build156modules (app359.01kB/gzip111.30kB, CSS9.40kB/gzip2.70kB). PASS verify-p07.cjs desktop/320px simulated scoped-contact/no-directory/reload-withdrawal/mail-encoding/storage/runtime checks; captures inspected/shown. Earlier failed sponsor test timing and TS mock literal fixed/rerun, retained in P07 ledger. Plan/tasks locally checked off; no provider gate erased.

P02–P06 external blockers retained: Docker/Podman absent; .env.local/provider references unavailable, Google disabled; real Supabase PostgreSQL17/Auth/PostgREST, official CLI types, real school/external Google PKCE/consent/callback, old guest JWT revoke/renew/expiry/sponsor-loss, deployed raw-token/body logging, true parallel-session request/version races and human UAT. No remote reset, provider config change or service-role substitute. Approved roster/FIN/MCD/sponsor authority, privacy custodian/basis/retention, HTTPS origin and approved logo remain open.

## Preview / custody / usage

Existing dev http://127.0.0.1:5173/preview retained/requested (host queued). P07 actual UI extension shown through labeled fictional test-only gateway screenshots; no fixture endpoint ships. No agents/chats/worktrees/dependency changes, PR/main merge, provider/website deployment or messages/invitations.

Standing user authorization: reviewed checkpoint commits/pushes to public David-GY/TEDxAteneo2627 branch codex/core-build-checkpoints. Start/local/remote1f782e8 verified; final P07 snapshot pushed/fetched and exact commit/tree plus clean worktree verified after this ledger, reported in chat. No unrelated changes present at start.

Shared usage16 →24 →30 →34 →36 →38%, reset1792834180; effective allowance40points, wind-down51used, ceiling56used. Shared-account observations, not exact attribution. No reset/purchase/wait. Finished local scope early; further P07 work requires actual provider/human proof.

## Next smallest action

After approved local runtime/provider setup, verify loopback target, migrate/seed synthetic Supabase17, compare official types, execute scoped authenticated API assertions and two real concurrent connections (same version and identical key), check old revoked/expired JWTs and deployed log redaction. Record human acceptance and approved privacy/retention policy before activation. Resume P07 with CONTINUE; P08 is separately code-eligible only.
