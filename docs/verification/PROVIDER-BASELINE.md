# Hosted provider baseline — October28,2026

Status: **blocked_external** for the full five-gap verification programme. The initial hosted database deployment is complete; real Google/member/guest/file/race/worker/human/recovery acceptance is not complete.

## Actual target and authorization

Owner identified https://wyurosneoxfqqrrvstke.supabase.co and authorized provider changes in this chat. Dashboard project is TEDxBackend, on its default main branch labeled PRODUCTION, free plan. No project/branch/billing/cap was created or changed. Before mutation, read-only dashboard and CLI queries independently observed PostgreSQL17.11, zero public tables/columns/API functions, zero Auth users/buckets/objects and no migration tracker. Empty was verified, not inferred from the branch label. CLI login was authorized by the owner and completed with the signed-in account; credentials remain CLI-managed outside Git. No credential values were copied to this document or evidence.

## Completed provider work

- Prepared a checksum manifest for the43 source migrations from application commit a37ea8f8a5e3c63282c08dc40c9930a7e4084129. The lexical bundler removes only top-level transaction wrappers, preserves quoted procedural bodies and adds empty-target/PostgreSQL-major/catalog/RLS guards.
- Ran the entire bundle against hosted PostgreSQL17.11 inside BEGIN…ROLLBACK. It passed107table/1098column/140non-trigger-public-function assertions. A subsequent hosted query again found zero application objects/buckets and no migration tracker, proving the validation rolled back.
- Linked only wyurosneoxfqqrrvstke. CLI dry run listed every source migration. Applied those43 normal versioned migrations with the pinned Supabase2.122.0 CLI, `--skip-vault` and no `--include-seed`; no fixture seed, reset, roster, user or real authority was inserted.
- Fresh hosted inventory: **107tables/1098columns/140public API functions**,43tracked migrations, one private work-private bucket, zero Auth users and file objects. All107tables have RLS; no application table grants anonymous SELECT. Raw authenticated finance SELECT/private lineage-view SELECT and anonymous access-publication EXECUTE are denied. Bucket is private with5MiB limit.
- Generated official public TypeScript types from the real provider. Table names/column names/column representations/function names/argument names match the local generated inventory:107/1098/140, zero observed representation or argument-name differences. This is a structural comparison, not proof of every runtime RPC return/SDK operation.
- Real HTTP checks with the existing public publishable key: Auth health200; unauthenticated has_capability, correctly formed publish_access_change and finance_cases raw read are401/SQL42501. No service key was used as a user token. Empty data does not prove cross-user row/byte isolation.
- Ran the actual linked security advisor. It returned136WARN findings, all `authenticated_security_definer_function_executable`. No blanket waiver or green security certification: the guarded RPC architecture intentionally uses definer functions, but real authenticated negative checks remain required. The catalog additionally records16RLS-enabled tables without FORCE, all owned by a BYPASSRLS role; this owner/infrastructure boundary needs explicit production review. Changing FORCE alone would not prove that owner boundary closed.

## Still missing, in dependency order

| Gap | Current position / next required input |
| --- | --- |
| P02–P05/P12 real Auth/JWT/Storage | Hosted schema/private bucket/API grants now observed. Google is disabled, Auth has zero users, Site URL is still http://localhost:3000 and redirect list is empty. No approved HTTPS app origin is configured or discovered. Need an organization-controlled Google OAuth client, exact local/hosted callback selection, secure client-secret entry and approved real school/external test accounts/roster. Then run actual PKCE, current/old-token, user/guest and upload/download/hash/revoke tests. |
| Independent-session races | Prepared a two-user P34 HTTP race/exact-retry runner; not executed remotely. It requires two distinct current authenticated grantors with approved synthetic same-unit ceilings. It does not claim database PID/lock-overlap proof. Remaining P07/P14/P16/P17/P21/P26/P27/P30/P33/P34 business races need separate current fixtures and observations. |
| FIN/MCD institutional routing | Owner deferred decisions and requested expansion capacity. No real policy/designation or threshold was invented. Existing typed adapters remain single-stage/one-reviewer until an approved new versioned mapping is implemented. See OPEN-DECISIONS.md. |
| P30 deployed operation | Dashboard says Deploy your first Edge Function: no files or dispatch-notifications function is deployed. Runtime/secrets/gateway/manual invocation/known-event delivery/failure recovery remain pending. No scheduler or external adapter/message was added. |
| Privacy/UAT/recovery | Templates/requirements below are preparation, not observed approval or human/restore evidence. No retention policy, named custodian or real restore has been invented. Sensitive production activation remains gated. |

## Executable verification tools

`node --test scripts/test-provider-verification.cjs scripts/test-provider-race.cjs scripts/test-provider-migrations.cjs` tests the tools locally. Injected transport always says test_only; it cannot produce live provider evidence. Missing inputs produce blocked/exit2 before a provider request. Production/wrong hosts, elevated JWTs, expired bearer substitutes and redirects are rejected. Results contain no tokens, emails, private rows, file bytes or signed URLs.

Copy provider-target.example.json to the ignored `test-results/provider-verification/target.json`; fill only approved target/account/fixture IDs and environment-variable **names**. Keys/JWTs belong in the secure invoking environment, not JSON/source/chat. `member` and `otherUnit` need the actual membership IDs; negative and guest profiles use null. For scope-ended profiles retain a still-cryptographically-valid token issued before the documented suspension/revocation/expiry, plus scopeEndedAt/change evidence. A JWT that simply expired cannot prove current DB revocation.

Optional profile sharedWorkId/privateWorkId select the expected scoped fixture. Optional `asset` contains its finalized id/workId/sha256/size. The tool retrieves its authorized metadata and verifies positive Edge bytes/hash before checking direct/list/sign denials. Normal Edge downloads may write their existing redacted access audit; no upload, source replacement, invitation, seed or reset is performed. Keep fixtures synthetic. Without a file fixture the Storage gate remains unverified.

Run `node scripts/provider-verification.cjs test-results/provider-verification/target.json` only after the prerequisites are real. For the race, add `race: {allowSyntheticRolePublication: true, unitId: <approved unit UUID>}` and run `node scripts/provider-race.cjs test-results/provider-verification/target.json`. It creates at most the expected unused immutable ordinary committee.manage role definition from the winning request, and performs the identical retry. It does not assign authority or delete cleanup records. It must never be pointed at real-data production by relabeling a config file.

`node scripts/provider-migrations.cjs` reproduces the historical rollback-only validation bundle and migration-plan.json. Its empty-target guard deliberately rejects this now-populated project. Do not reset this project or rerun the bundle as an upgrade; future changes use new migrations. Inventory-only command:

```powershell
pnpm exec supabase db query --linked --project-ref wyurosneoxfqqrrvstke --file docs/verification/provider-inventory.sql --output-format json
```

The CLI requires both `--linked` and the explicit project override. It prints an initialization line before query JSON; parse only the JSON envelope. Do not enable debug logs or print API key listings. Targeted source/probe corrections are retained in the evidence: initial CLI agent-mode login needed explicit interactive text mode; query target flags corrected; rollback function count excludes triggers; initial finance probes used nonexistent id/work_item_id rather than request_id and the initial publication probe omitted arguments. Those responses were not relabeled security passes. The corrected requests returned permission denials.

## Scope and provenance

Source application/migrations are unchanged in this phase; additions are verification tools, SQL inventories, plans and receipts. Original synthetic P34 preview remains loopback-only and separate from hosted deployment. Hosted frontend, Google provider, live participants, Edge functions, policy activation, schedules and restore were not deployed/performed here. Owner deferred institutional decisions; a connected organizational source was read for context, but its notes were not imported as authority or copied into Git. Original review checkpoints remain historical and are superseded only for these actually observed provider facts.

Source references: [Supabase authenticated user lookup](https://supabase.com/docs/reference/javascript/auth-getuser), [Storage access controls](https://supabase.com/docs/guides/storage/security/access-control), [Edge authentication](https://supabase.com/docs/guides/functions/auth). These inform the probes; documentation is not execution evidence.
