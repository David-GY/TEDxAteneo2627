# Local identity database — P02

P02 defines ten identity tables with no initial application access. P03 adds minimal authenticated policies/read helpers and own-field writes. P04 tightens those helpers to verified school Google/core identity and adds controlled roster linkage; see `docs/integrations.md`. Real provider verification remains pending. No real organization roster or approved authority is seeded.

## Run SQL checks without Docker

```powershell
pnpm test:identity
pnpm test:authorization
pnpm test:google-auth
pnpm db:types
pnpm db:types:check
```

The harness creates a fresh **in-memory** PGlite PostgreSQL database, with no URL/path option or remote connection. It supplies minimal `auth.users(id)`, `auth.uid()` and API-role contracts, then runs the actual migration/seed/test SQL. It simulates legacy default grants before migration so revocation is exercised. Temporary permissive test policies/grants are rolled back. The seed is run twice and checked for duplicate-free repeatability. This is real PostgreSQL SQL execution, but **not the full Supabase platform**.

Current harness: PGlite 0.5.11 / PostgreSQL 18.6. Supabase config targets PostgreSQL 17. Full PostgreSQL 17, Supabase Auth, PostgREST and CLI integration remains unverified until the container runtime is available. Test evidence is in `docs/build/evidence/P02-identity.json`.

## Full local Supabase prerequisites and remaining check

Node/pnpm are already installed; Supabase CLI is pinned as a dev dependency (2.122.0). On this Windows host, Docker Desktop or a compatible running container runtime is required. Docker/Podman are currently absent. Native process mode is currently documented for Linux and Apple-silicon macOS, not this Windows environment. See [Supabase local runtimes](https://supabase.com/docs/guides/local-development/docker-and-native-runtimes) and [CLI workflow](https://supabase.com/docs/guides/local-development/cli-workflows).

After supplying the container runtime, from this repository:

```powershell
pnpm exec supabase start
pnpm exec supabase status
```

Verify project `TEDx`, API loopback 54321 and local DB loopback 54322 in status. Do not copy provider secrets into client settings or evidence. Only after confirming that local target, the authorized fictional local reset/check is:

```powershell
pnpm exec supabase db reset --local
pnpm exec supabase test db --local supabase/tests/google_auth.test.sql
pnpm exec supabase gen types --local --schema public
```

The final command prints types; compare them with the catalog-generated types, do not overwrite a working file with failed-command output. These commands have **not passed here**: status/reset/type generation stop before database access because the runtime is missing. P02's historical zero-policy SQL suite requires a P02-only migration boundary (`pnpm test:identity` preserves it); do not run that file against P03 policies. Never use `--linked`, a remote `--db-url`, remote seed/reset or `db push` as a substitute. No project is linked or provider configured. Local seed contains only example.invalid addresses, clearly fictional labels and unlinked invited members; it sends no messages or invitations.

## Identity contracts

| Entity | Integrity and boundaries |
| --- | --- |
| organizations | UUID; canonical lowercase slug; active/archived |
| terms | Organization FK; ordered start/event/close dates; draft/active/frozen/archived; at most one active term per organization |
| members | Stable UUID; organization; generated lowercase/outer-trimmed email unique within organization; nullable unique auth.users FK; invited/active/suspended/archived |
| term_memberships | Same-organization term/member FKs; unique term/member; core/guest, pending/active/suspended/expired/revoked; bounded dates; nullable affiliation_tag |
| private_profiles | One per member, same organization; optional contact/course/year fields and explicit per-field sharing flags defaulting false |
| org_units | Term-bound stable UUID/code; independent delivery_committee/review_service flags; archived_at |
| unit_memberships | Same-organization/term member, unit and approver FKs; explicit deployment type, active/expired/revoked status and start/end |
| roles | Term-bound UUID/code and active/retired state; privileged classification is metadata, not a grant |
| role_permissions | Same-term role FK; fixed capability vocabulary with generated resource/action/privileged columns and constrained allowed scope |
| role_assignments | Same-term member/role/optional unit/grantor FKs; own/term/unit scopes; unit required exactly for unit scope; bounded dates and active/expired/revoked |

Email normalization deliberately folds case and outer spaces only. It does not invent Gmail alias equivalence or enforce the school domain here: approved roster/domain/verified guest rules belong to P04. `auth_user_id` is never filled from user-editable metadata. Member insertion and identity/email/org changes require a trusted database role even if a future policy accidentally allows broad profile edits. No client role can write these tables in P02.

All ten tables have created/updated timestamps, created_by/updated_by auth-user FKs and integer version. Invoker triggers stamp actors from `auth.uid()` and server time, preserve original creation provenance and advance version; submitted actor/version/timestamp values cannot override them. Trusted local bootstrap has null actor because it has no signed-in session. The approved_by/granted_by member references are currently written only by trusted SQL; future server commands must derive and validate those actors, not accept arbitrary caller IDs. No grant RPC is exposed by P02.

At the **P02 boundary**, RLS is enabled/forced with zero policies, table/column access denied to API roles, and invoker trigger helpers have empty search_path/revoked direct execution. **P03 supersedes that initial state** with minimal authenticated policies and five read/predicate helpers; see `docs/permissions.md`. Service-role RLS bypass is not a table grant. Transactions commit only after grants/RLS are set. Local config disables auto-exposure. Defaults are revoked for the migration owner; future migrations using another owner must verify that owner's defaults too. See [Supabase RLS and grants](https://supabase.com/docs/guides/database/postgres/row-level-security).

P03 must check effective membership/account/term states, current dates, matching permission/assignment scope, role state and explicit authority. Stored `active` flags alone do not defeat expiry. Neither affiliation, unit service/delivery flags nor a privileged label grants access. Unit deployment does not automatically create a role assignment. Freeze rules, delegation ceilings, immutable audit and permitted commands belong to their owning steps. No work scope/placeholder work UUID exists; P07 must add a real FK when work_items exists. No official committee tree or eight-committee roster is assumed.

## Generated types

`src/lib/database.types.ts` is generated by catalog introspection of a fresh migrated database, not hand-maintained SQL parsing. Row/Insert/Update nullability/default/generated-column behavior and public FK relationships come from PostgreSQL catalogs. Generated values use `never` in write shapes. Auth-schema relations and trigger-return functions are not exposed as public application relationships/RPCs. This does not grant write permission.

The generator covers the ten tables and six public helpers (through P04), including arguments/defaults/table returns from function catalogs, and fails on unknown scalar types/table-count drift. P02/P03 scripts stop at their historical migration boundaries; current authorization uses test:google-auth. When future steps introduce tables/views/RPCs, extend/replace the generator, preferably with the full Supabase CLI generator once available. Full CLI type comparison remains pending.
