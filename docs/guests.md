# Guest invitation contract (P05)

This implementation is blocked from live activation by the P02–P04 runtime/provider gates. It sends no email. Core access still requires the approved school roster. Guest invitations create no member, term membership, deployment or role assignment.

## Authority and scope

Only a current core sponsor with a dated, active **roles.manage / term** assignment may create, list, renew or revoke their own invitations. Actor/sponsor derive from auth.uid/current_term_membership. Sponsor school identity, roster email, organization, term, dates and grant are checked again for guest context resolution. Suspension, expiry, loss of grant, frozen/closed term or changed verified email denies guest access.

Before P07 supplies real work_items, every invitation has constrained scope_mode `awaiting_record_attachment`: **zero shared records**, no directory, unit or membership-wide access. No invented work IDs or dangling FKs. P07 must attach exact record grants through real FKs and enforce current invitation checks on every record/file/join/count route. Guest context is not itself permission to read work. Multiple invitations select the latest-expiring eligible context; no cross-organization union.

## Storage and commands

guest_invitations has same-term sponsor FKs, canonical email (outer trim/lowercase only), SHA-256 token hash, 1–14-day expiry (default 14), redemption UID/time, revocation time, version, request UUID and optional replacement invitation. Two random UUIDs supply a 64-character bearer with about 244 random bits. The bearer is returned once, never persisted in tables/audit/application logs. guest_invitation_events records invitation ID, actor UID, event, time and request ID transactionally, without email/token payload. Both tables have forced RLS and no direct API-role grants. Infrastructure owners retain bypass power.

| Authenticated RPC | Contract |
| --- | --- |
| create_guest_invitation | term ID, exact email, request UUID, optional expiry; replacement ID + expected version for renewal. Returns ID, token/null, reused flag. |
| redeem_guest_invitation | Raw token; exact confirmed auth.users email must match provider-managed verified Google identity and invitation email. Row lock/single use; generic denial. Returns redeemed state, expiry, sharedRecords=0. |
| revoke_guest_access | ID, expected version, request UUID; sponsor check, row lock/version check, transactional audit. Returns revoked state. |
| list_guest_invitations | Term ID; only current sponsor's safe metadata. No token/hash/redeemed UID. |
| resolve_auth_context | Preserves private core resolver; otherwise minimal audience=guest context with guestAccessId/displayName/organizationId/termId/expiresAt/capabilities=[]. No core member/membership IDs. |

Creation retries serialize on sponsor row and reject changed email/explicit expiry/replacement. They never return the bearer again; after a lost response, refresh and renew. Renewal is create_guest_invitation with replacement ID/version: atomically invalidates old invitation/access and creates a new single-use link. Revoke retries with the same request UUID return the prior outcome; stale versions fail. Errors: 42501 permission/unavailable, 22023 validation/request conflict, 40001 version conflict. Browser messages omit raw service diagnostics. Audit is immutable to API roles. No email/outbox exists.

## Browser

/guests uses real RPCs, exact email/duration/scope preview, one-time copy/select fallback, renew/revoke. Navigation is presentation; loader/database enforce authority. Clipboard success appears only after the write resolves. Links remain only in React memory and can be hidden.

/guest/redeem#TOKEN consumes the fragment and removes it from history. HTTP requests never include fragments; no token enters query strings, browser storage, return path or analytics. OAuth clears memory: sign in, then reopen the original invitation link. External Google accounts use the same approved provider; External consent/institutional policy must be configured/tested first. The data model is provider-independent; current identity verification only admits Google, with no untested OTP.

Guest navigation/direct core/admin paths are restricted to guest destinations. Database core policies reject guest subjects. Navigation/auth/focus/poll/expiry rechecks apply; revoke requires no new login. No work data is cached, and shared areas remain empty until their owning steps.

## Verification and gates

pnpm test:guests runs fresh in-memory migrations/seed, P04 assertions on full P05, then named P05 assertions as authenticated subjects. Tests cover actual changed rows, forwarded/unverified email, one-use/expiry, retry/version failures, directory/table/self-grant denial, revoke under unchanged subject, renewal, sponsor grant loss, hashed-only storage/audit and fixed function security. Frontend tests cover route isolation, no stored bearer, sanitized adapter failures and confirmed-only copy. Browser evidence tests actual unconfigured production redemption and a labeled test-only simulated sponsor gateway; no fixture endpoint ships.

Missing: Docker/Podman/configured Supabase PostgreSQL 17/Auth/PostgREST, official CLI type comparison, approved Google External consent/real callback, actual old-JWT revoke/renew/expiry/sponsor-suspension requests, deployed parameter/body log redaction, privacy/authority approval and human UAT. Embedded PostgreSQL 18.6/auth-shaped subjects and simulated browser gateway do not prove these.

After verifying the local target and completing integrations.md setup, run `pnpm exec supabase test db --local supabase/tests/guests.test.sql` and current Google SQL. Test REST/RPC with real authenticated user JWTs; never substitute a service key or remote reset.

## P07 effective record attachment

P07 now supplies record_grants with a same-term FK to guest_invitations and work_items. New/renewed invitations still create zero records. grant_work_access explicitly attaches one owned draft record to the owner's own current valid invitation, read-only, with bounded expiry and expected work version; no implied parent/sibling/unit/directory permission. Effective access checks exact email/redemption, current sponsor/expiry/revoke and grant on every read. list_guest_invitations now returns computed scopeMode and sharedRecordCount; redemption returns the actual attached count. The stored legacy scope_mode remains a P05 creation marker, not authorization. Guest contact reads may return only active explicitly shared work-owner name/exact-school organization route; never private profile/course/phone. A record revoke removes that contact on next read. Frontend accepts validated explicit_records as well as unchanged empty invitations. No guest edit/approval or external messages introduced. Real old-JWT/PostgREST checks remain blocked.
