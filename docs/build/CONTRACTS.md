# Build contracts

Established by P00, October 24, 2026. This file records agreed interfaces, not a claim that future features are implemented. Reuse these boundaries and update only the section owned by a step.

## Tooling and frontend entry

- Package manager: pnpm 11.25.0; one pnpm-lock.yaml. Scripts are ordinary package scripts runnable as `pnpm <script>`. No npm executable was available on the initial workspace PATH.
- Node: 24 LTS recommended; package engine matches the supported Node 22.12/24/26+ lines used by the selected test tooling.
- Required commands: `pnpm typecheck`, `pnpm lint`, `pnpm test`, `pnpm build`. `pnpm dev` serves loopback port 5173; `pnpm preview` serves built files on 4173. `test:e2e` will be added with a real browser suite, not a successful no-op.
- React entry: `src/main.tsx`; router: `src/app/router.tsx`. `createAppRoutes(environment)` returns route definitions suitable for browser or memory-router testing. `createAppRouter()` reads only the two allowlisted public variables and creates the browser router.
- Current routes: `/` setup overview inside P01 AppShell; navigation destinations have explicit unconnected empty states; `*` not found. Root and destination `errorElement` provide generic recovery without exposing diagnostics. These pages expose no records or business actions.
- No backend requests, auth sessions, Supabase SDK, fixtures on production screens, or domain data exist in P00.

## Accessible shell (P01 implemented)

`src/app/AppShell.tsx` owns desktop and labeled mobile navigation, a skip link/main landmark, route focus and loading, and the More disclosure with Escape/focus restoration. `NavigationContext` in `navigation.ts` is `{ audience: 'setup' | 'core' | 'guest', capabilities: readonly NavigationCapability[] }`. `getVisibleNavigation` and `getMobilePrimaryNavigation` provide presentation only; they neither establish authorization nor grant access to future APIs/routes. Do not derive capabilities from MEAn affiliation. The setup context is explicit and unconnected; no member identity is inferred.

Shared patterns: `PageHeading({title, description?})`, `Panel({title, children, className?})`, `EmptyState`/`ErrorState` with title/description/optional React action, `LoadingState`, and `TextField` with input attributes plus id/label/hint/error. Field descriptions and validation are associated through stable IDs. Each future error must provide a real recovery action. Use `src/styles/tokens.css` and `global.css`; these replace P00's `src/styles.css`. Karla is bundled locally through Fontsource. DESIGN.md records layout/tokens and temporary text identity.

Optional AppShell identity labels are presentation props, never actor identity. No synthetic identity is passed on application routes. The browser regression harness injects fictional labels only into its test DOM. Runtime and production pages remain free of synthetic metrics and success simulations.

## Public environment (implemented)

`readClientEnvironment(input)` in `src/lib/env.ts` takes optional `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` strings. It returns either `{ state: 'not_configured', issues: string[] }` with static safe messages, or `{ state: 'configured', supabaseUrl, supabasePublishableKey }`. Configured means syntactic settings only, never connectivity, membership or authority.

URL: HTTPS origin, or HTTP on exact loopback hosts localhost/127.0.0.1/::1; reject embedded credentials, paths, query/hash and malformed URLs. Key: modern `sb_publishable_` format only; secret and legacy JWT formats fail. Values are not echoed by errors/pages. Reading the whole import.meta.env object is prohibited. Vite's production build also rejects nonblank invalid/partial public settings before bundling. All VITE-prefixed settings remain public by design; no validation permits a secret to be shipped safely.

## Identity storage (P02 implemented; Supabase-stack verification blocked)

Migration: `supabase/migrations/20261024000100_identity.sql`. Detailed table/column contracts and local commands: `supabase/README.md`. Ten public tables: organizations, terms, members, term_memberships, private_profiles, org_units, unit_memberships, roles, role_permissions, role_assignments. Composite organization/term FKs enforce membership, unit, role, approver and grantor consistency. UUIDs identify rows; normalized_email is generated from lower(btrim(email)), unique per organization. Auth linkage is nullable/unique and references auth.users; never derived from metadata. Trusted SQL controls roster insertion/email/linkage; a trigger also prevents ordinary-role identity changes even with a permissive profile policy.

All editable rows carry created_at/created_by/updated_at/updated_by/version. Actors are auth-user FKs stamped from auth.uid(); trusted unauthenticated local bootstrap has null actors. Creation provenance is preserved on updates. Timestamp/version/actor inputs cannot override trigger stamps. approved_by/granted_by reference same-term memberships and currently have no client write path; future authorized commands must derive/validate them server-side.

Dates and explicit states coexist: P03 must check current effective_from/to, joined_at/ends_at, active account/membership/assignment/role and unfrozen term, rather than trusting a stored active label. Term-membership affiliation_tag is nullable/descriptive; never a capability input. Delivery/review flags are independent. Private profiles are separate, optional and default to no sharing. No unit deployment implicitly creates a grant. Fixed capability vocabulary/scope checks live in role_permissions, with generated resource/action/privileged metadata. Privileged metadata alone confers nothing. No work scope or dangling work UUID exists; P07 adds a real work FK.

Initial exposure: all ten tables enable/force RLS, zero permitted policies, all grants revoked from PUBLIC/anon/authenticated/service_role, no client schema CREATE, no directly executable public helper. Defaults are revoked for the migration owner; local auto-exposure is false. Trigger helpers are security invoker with empty search_path. P03 owns narrow grants, projections, effective-authority helpers and delegation limits. No auth/domain/private-data activation is implied by this schema.

Types: `src/lib/database.types.ts`, catalog-generated via `pnpm db:types`; `pnpm db:types:check` verifies drift. Current generator owns only P02 tables/scalars and excludes auth-schema links/trigger functions from public relationships/RPCs. Extend or replace it when P03 introduces helpers/views/RPCs; full Supabase CLI comparison awaits Docker. Named SQL checks run with `pnpm test:identity` in isolated in-memory PostgreSQL 18.6/PGlite, with minimal auth contracts. Full Supabase PostgreSQL 17/Auth/PostgREST migration/seed/test/type generation remains blocked by the absent container runtime, not marked complete. No remote project is linked.

## Identity authorization (P03 implemented; full-stack check blocked)

Migration `20261024000200_authorization.sql` adds five authenticated-only read/predicate helpers with fixed empty search_path, trusted RLS-bypassing owner and auth.uid-derived caller: current_term_membership(uuid), owns_active_member(uuid,boolean=false), has_capability(uuid,text,uuid=null), read_directory(uuid) and explain_access(uuid). Exact scope/expiry/response contract: `docs/permissions.md`.

P03 supersedes P02's initial zero-policy state with column-limited safe reads, own-member/membership/private-profile policies, own display-name/affiliation/profile writes, and unit metadata through workspace or exact scoped capability. Raw member identity, other private profiles, grant/deployment/role writes and membership status/expiry/org fields remain closed. No privileged command grants or impersonation. Core capability checks require active dated assignment/role and, for unit scope, matching active deployment; guests do not inherit core capabilities. Affiliation/metadata never grant access. Frozen-term reads remain, own profile writes require an active unfrozen term.

`pnpm test:authorization` uses all migrations plus seed and tests unprivileged authenticated principals with distinct subject claims, including actual positive row changes. `pnpm test:identity` now explicitly stops at P02 to preserve its pre-policy regression boundary; do not run its zero-policy SQL on the post-P03 schema. The type generator introspects all five function signatures and table returns; scalar returns conservatively include null. P02-only generator notes above are historical, superseded here.

P02/P03 full Supabase PostgreSQL 17/Auth/PostgREST/JWT and official CLI type verification remain blocked by missing Docker. Embedded PostgreSQL 18.6 results are SQL/API-role evidence, not actual HTTP verification. Provider linkage and audit/live activation remain gated. Project owners retain documented infrastructure bypass power.

## Google/session admission (P04 implemented; live provider blocked)

Migration 20261024000300_google_auth.sql adds a non-exposed private verified-school-identity predicate and authenticated-only resolve_auth_context() (no actor/email input). P03 current_term_membership now additionally requires canonical confirmed auth.users email, matching provider-managed verified Google identity, exact student.ateneo.edu domain, server roster email/link and core membership. Guests remain closed until P05. All P03 policies inherit this stricter gate, so an old token does not bypass suspended/expired/canonical-identity changes.

resolve_auth_context locks/rechecks exactly one approved roster match, links only unlinked or same-auth-UID members and activates an invited account only when its core term membership is already active/current. It never creates a roster or role. Repeated reads do not rewrite linkage. Returns safe denied or authorized member/organization/term/membership/expiry/capabilities context. See docs/integrations.md for exact shape, identity provenance, redirects and setup. Trusted actor/version stamps apply to linkage updates; immutable audit/privileged management remain future activation gates.

src/lib/supabase.ts dynamically creates pinned Supabase JS with PKCE and explicit code exchange. Auth gateway verifies getUser then calls trusted RPC; route loaders recheck navigation, auth events/focus/poll/expiry trigger revalidation. Route data is never authorized by a browser email check. Login, callback, account switching/sign-out have safe errors; exact return-path/origin allowlists; callback parameters removed/no-referrer. `/preview` is development-only and does not exist in production. No config produces Setup needed rather than protected navigation. src/features/auth owns these contracts; current public types include six helpers.

test:identity and test:authorization preserve P02/P03 historical migration boundaries. test:google-auth covers the current P04 schema using provider-shaped local fixtures; verify-p04.cjs tests actual unconfigured production routing/recovery and preview exclusion. These do not replace real Google/JWT/PostgREST verification. Google remains disabled, no secret references supplied, Docker unavailable; P02/P03 blockers remain.

## Stable identifiers and database ownership (cross-feature conventions)

P05 supersedes earlier guest-closed notes; see docs/guests.md. Two forced-RLS, direct-grant-denied tables and four authenticated invitation RPCs provide verified-email binding, hashed one-use tokens, expiry, sponsor-bound administration and redacted audit. resolve_auth_context wraps the unchanged private core resolver and may return minimal guest context without core membership/capabilities. Zero records shared until P07 supplies scope FKs. Types now cover 12 tables/154 columns/10 public functions. Historical P02/P03/P04 scripts preserve migration boundaries; test:guests also reruns P04 on full P05. User separately authorized GitHub checkpoint commits/pushes; app/provider deployment remains gated.

- Business IDs: UUID strings. Database-generated IDs and canonical row relations, not display labels/array positions, identify records. Display tracking IDs are separate and term/namespace scoped.
- Same-organization and same-term FK/command checks accompany membership/unit/work references. No inferred access inheritance from a linked parent or child.
- PostgreSQL is authoritative for current membership, scoped grants, sensitive reads, workflow/state transitions, money, acceptance, immutable decisions, audit and idempotency. The browser is presentation, not an authorization boundary.
- Database RPCs use snake_case and derive the actor from authenticated session identity, not a submitted member/user ID. Client adapters expose explicit DTOs and do not duplicate server authority. Exact per-feature DTOs/schema are added by their owning prompts rather than invented now.

## Mutation, retry and error conventions (future implementation)

- An update/transition supplies `expectedVersion` (integer matching the current row revision) and `idempotencyKey` (fresh UUID per intended user action). A create has no previous version. Use snake_case equivalents in SQL arguments and record the mapping in the feature contract.
- Idempotency uniqueness is actor + command + key; identical retry returns the original outcome. Reusing a key with a changed payload fails validation. A stale version returns a conflict without applying changes.
- Errors use a stable code plus safe human message and optional field-error map. Initial codes: `PERMISSION_DENIED`, `VALIDATION_FAILED`, `STALE_VERSION`, `DEPENDENCY_BLOCKED`, `MISSING_APPROVER`, `QUOTA_LIMIT`, `CONFLICT`, `UNAVAILABLE`. Do not return private row titles/contents or raw service diagnostics to an unauthorized caller.
- Record business change, append-only redacted audit and deduplicated outbox in the same database transaction. Delivery after commit cannot undo the recorded business decision. Never report success for a missing RPC.

## Dates, money and privacy conventions (future implementation)

- Display timezone: Asia/Manila using explicit timezone formatting. Datetime storage: UTC timestamptz/ISO 8601. A date-only deadline remains YYYY-MM-DD; its defined local cutoff is 23:59 Manila, not an implicit UTC midnight.
- Preserve original and current deadlines and reasons. PHP amounts are integer centavos, never floating-point pesos. P24 defines exact quantity/rounding and API range/serialization; do not coerce out-of-safe-range PostgreSQL bigint values to JavaScript numbers.
- MEAn affiliation is descriptive only. Department deployment is explicit scoped authority. RLS and private file access must exist before protected data is exposed.
- Synthetic local and synthetic staging are separate from production. No cloning real receipts/evaluations into previews. No elevated keys, private content or raw tokens in client bundles, test output, analytics, audit payloads or Git.

## State and handoff protocol

`docs/build/STATE.md` is the concise latest handoff; `docs/build/steps/PXX.md` holds per-step evidence. Status: not_started / in_progress / blocked_external / ready_for_review / complete. Passing local interfaces may support independent later coding while an external check remains blocked, but live activation/release cannot bypass the missing evidence.

Record exact checks/results, unavailable prerequisites and next smallest action. Resume a partial step using `build-prompts/CONTINUE.md`. Do not auto-execute successors, commit/push, deploy, send invitations, or reset remote data. Keep a live local preview visible while working, per the user's preference.

## P06 partial directory projection

See docs/people.md and docs/build/steps/P06.md. Migration20261024000500_directory.sql adds authenticated read_people_directory/read_process_contacts RPCs, both fixed-search-path, capability-gated, current-membership reads over existing P03/P04 authority. No raw profile grants broadened. Consent-filtered optional values, unique people/current units/roles and primary/backup assignments. Types now12 tables/154 columns/12 public functions. /people uses real RPCs. Guest-wide directory denied; own/shared contact support pending. P06 remains in_progress: profile editor/private-value and visibility commands/audit still required. P02–P05 external verification blockers persist.
