# Identity permissions — P03

**P04 supersedes the admission prerequisite below:** current_term_membership now also requires canonical confirmed school email and matching verified Google identity, and accepts core membership only. Guests are closed until P05. See `docs/integrations.md`. The P03 regression script preserves its earlier migration boundary; current admission regressions use test:google-auth.

This contract describes implemented SQL boundaries, not a live login or provider verification. All source tables retain forced RLS. Client navigation is presentation only. Tests execute as non-superuser, non-BYPASSRLS `authenticated` and `anon`, using distinct synthetic subject claims. Full Supabase/PostgreSQL 17/PostgREST/JWT validation is still blocked by the absent container runtime.

## Principal and scope

`auth.uid()` must match an active member's server-controlled auth linkage and an active term membership. Membership must be within joined_at/ends_at; organization must be active; term must be active/frozen and within its Manila start/close dates. Start is inclusive and end timestamp exclusive. School domain, MEAn affiliation and token metadata never grant membership. P04 owns verified-provider/domain/roster linkage; these helpers do not auto-provision it.

Effective capabilities require an active, dated role assignment, active role, matching fixed capability/allowed scope and current core membership. A unit scope additionally requires a matching active, dated deployment and an unarchived unit. Deployment alone confers no capability. A term grant does not turn into an arbitrary unit grant. Service/delivery flags and privileged labels confer no access. Guests cannot inherit core capabilities even if erroneously assigned a core role; active guests retain only their own identity/profile settings here. Shared work is added by its owning feature, not invented by P03.

## Read helpers

All five helpers are STABLE, SECURITY DEFINER, fixed `search_path = ''`, and schema-qualify relations. Their trusted migration owner must bypass RLS to avoid recursive membership policies. Only authenticated has EXECUTE; PUBLIC/anon/service_role have no direct grant. Each helper derives the caller from auth.uid(); no actor/impersonation parameter exists.

| Function | Result / limits |
| --- | --- |
| `current_term_membership(p_term_id uuid)` | Caller's eligible membership UUID or null |
| `owns_active_member(p_member_id uuid, p_write boolean default false)` | Whether target is the caller's eligible member; write=true also requires an active, unfrozen term. This target predicate does not impersonate the target |
| `has_capability(p_term_id uuid, p_capability text, p_unit_id uuid default null)` | Current matching capability; unit must match for unit scope; term/own scopes use null unit; unknown/invalid context returns false |
| `read_directory(p_term_id uuid)` | Core caller with directory.read gets eligible core member_id/display_name rows only; otherwise empty |
| `explain_access(p_term_id uuid)` | Caller's membership_id and effective role/capability/scope/unit/assignment-expiry metadata; invalid context gives null membership and empty grants |

Example explanation shape:

```json
{"membership_id":"own-membership-uuid","grants":[{"role_id":"role-uuid","capability":"department.review","scope":"unit","unit_id":"assigned-unit-uuid","expires_at":"assignment-end-timestamp"}]}
```

This explains current recorded grants, not approval eligibility for a future case. `expires_at` is assignment expiry; membership/deployment/term expiry or revocation may end access earlier. Current status is rechecked on every SQL statement. A neutral empty response does not reveal whether an arbitrary term exists. Support cannot use this interface to impersonate a user. Effective FIN/MCD case authority, MFA, self-approval and revision checks belong to later workflow commands.

## Direct API-role access

| Table / projection | Permitted behavior |
| --- | --- |
| organizations / terms | Safe context columns for caller's eligible terms/organization |
| members | Own id/organization/display_name/version only; UPDATE own display_name only |
| directory helper | Eligible core IDs/names only; no raw member SELECT for a directory join |
| term_memberships | Own eligible metadata; P06 revokes direct affiliation UPDATE in favor of audited owner commands |
| private_profiles | SELECT own row; P06 revokes direct INSERT/UPDATE including column grants; separate audited owner value/visibility RPCs |
| org_units | Ordinary active unit metadata with workspace.read, or only explicitly authorized unit metadata for scoped capabilities |
| unit_memberships / role_assignments | Own membership's grant/deployment metadata; may include own historical assignment rows, which are not proof of current authority |
| roles / role_permissions | Metadata for caller's currently dated assignments only; no mutations |

No client grant allows roster insertion, auth/email linkage edits, membership expiry/status/organization edits, deployment or role/permission/assignment writes, deletion, or private-profile key reassignment. PM/admin.configure does not bypass these restrictions or reveal other private profiles. Grant management remains closed pending separately authorized, audited server commands with delegation ceilings. No fake successful grant RPC exists.

Own profile edits are a built-in membership right, not a workspace-role escalation. Frozen terms allow reads but reject these profile/affiliation writes unless the member has another eligible active term. Allowed updates return real changed rows and advance server actor/version stamps; a zero-row update is not success. Denied SELECT can return zero rows under RLS; revoked column/table operations raise 42501. Clients must request explicit permitted member columns; `select('*')` on raw members fails because identity fields are excluded. Sharing flags are stored choices. P03 initially returned names only; P06 adds a separate projection that independently filters every optional field by its owner-controlled flag.

## Evidence and limits

P05 adds a separate invitation boundary; see [guest contracts](guests.md). Core helpers still require school/core roster membership. Invitation RPCs require the current sponsor's term roles.manage grant; guests inherit no core grants. Minimal verified-Google guest context shares zero records before P07. Guest tables have no direct API grants; private resolver/verifiers remain inaccessible. Revocation, expiry or sponsor authority loss denies current context under an unchanged authenticated subject. Real previously issued JWT transport verification remains blocked. P03 details below describe its historical boundary.

`pnpm test:authorization` applies both migrations and the fictional seed, creates rolled-back PM/head/member/associate/guest/nonmember/suspended/other-organization principals, then runs named P03 assertions. It checks direct SQL as the API roles, not service-role UI simulations. Fake administrative metadata cannot replace database grants. Positive writes assert changed-row count, values, actor and version. The P02 historical pre-policy suite remains available as `pnpm test:identity`; it applies only P02, since its zero-policy assertions intentionally precede this migration.

Generated types now include five catalog-introspected helper signatures. Scalar returns are conservatively nullable. Future table/view/RPC types must extend the generator; full official CLI comparison remains pending.

To finish full-stack verification, start a verified local Supabase project, apply/reset only that local synthetic target, run `pnpm exec supabase test db --local supabase/tests/authorization.test.sql`, then use locally issued authenticated-user JWTs for REST/RPC negative and allowed-write checks. Never substitute a service key as the principal being tested. Do not run the historical zero-policy P02 SQL against the post-P03 schema; validate that boundary in an isolated P02-only migration set. No actual HTTP/JWT/OAuth result is claimed by the embedded harness.

Project/database owners and sufficiently privileged infrastructure roles can bypass RLS, alter helpers and access data. Fixed search paths and end-user policies do not remove that infrastructure power. Keep console/credential custody separate, with the planned review/audit/backup controls. No production activation is authorized by local SQL success. Official references: [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [function security](https://supabase.com/docs/guides/database/functions), [PostgreSQL column grants](https://www.postgresql.org/docs/17/sql-grant.html).


## P06 current profile/contact boundary

See people.md. Core optional private values and disclosure are separate authenticated owner-only RPCs, with current authority, expected version, persistent idempotency and redacted transactional audit; heads cannot supply another actor/member ID or override disclosure. Affiliation is descriptive, term-specific and audited, never a privilege input. New events retain safe actor-name attribution; no private historical-profile lookup granted. Guest contact tables forceRLS/no direct API grants; read/edit derives verified invitation subject and rechecks sponsor/expiry/revoke. Guest own contact data does not share with sponsors/other guests. sharedContacts remains empty until P07 supplies real scope attachment. No broader raw member/profile grants.
