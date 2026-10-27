# Identity integration — P04

Current-status note (October27,2026): this document retains historical integration boundaries. P05/P07 scoped guests and later local modules now exist; earlier “until P05” statements are historical. Real Google/Supabase/JWT/Storage verification and identified HTTPS deployment targets remain unverified. Current implementation status and exact gates are in docs/build/STATE.md and docs/build/P00-P34-REVIEW.md; GitHub backup and loopback preview are not deployment receipts.

Implemented locally; real Google OAuth, Supabase PostgreSQL 17 and HTTP/API verification remain blocked. No provider credentials/project target were supplied. Docker/Podman are absent. Google is deliberately disabled in local config until its secret references and an approved provider project are supplied. No Drive/Calendar scopes or guest invitations are implemented here.

## Client flow and protected routes

Supabase JS **2.118.0** is pinned and loaded only for configured, approved application origins. Client settings remain the two explicit public variables in .env.example. `src/lib/supabase.ts` selects PKCE, persistent SDK session, auto-refresh and **detectSessionInUrl=false**. `/auth/callback` explicitly exchanges the code once per gateway instance, including React StrictMode effect replay. No service key is used. Raw provider errors are never rendered; code/error query parameters are removed immediately, and the page sets no-referrer.

`getSession` alone never grants entry: the gateway calls `getUser` and the database RPC `resolve_auth_context()` with no actor/email argument. The protected parent loader checks this on direct entry and every navigation. Auth events, window focus, visibility, 30-second refresh and membership-end timer revalidate access. SDK session failures close the route; database rules independently deny every stale membership/identity read. A visible shell is not authority for API operations. Browser display may lag an administrative change until revalidation; API policies remain the enforcement boundary.

Sign-out clears the current browser's Supabase session through the SDK; it does not claim to sign out every Google account/device. Account switching first confirms local sign-out then requests Google's select_account prompt. Failures remain failures and do not simulate success. Session tokens live in SDK browser storage, never source/evidence/logs; no private business data is cached by this slice.

Return destinations are an exact list of current workspace paths. External, protocol-relative, encoded, control-character, auth and preview paths fall back to `/`; queries/fragments are discarded. The sanitized destination is stored separately in sessionStorage, never included in the OAuth redirect. No storage access means a safe overview fallback. Preview is **development-only** `/preview`; its links still point to protected destinations. Production has no preview bypass. No synthetic records are included in login or protected pages.

## Trusted database admission

Migration `20261024000300_google_auth.sql` adds private `app_private.is_school_identity(uuid)` and authenticated-only, fixed-search-path `resolve_auth_context()`; it tightens P03 current_term_membership so existing direct API reads cannot bypass admission.

Admission requires all of:

- Canonical auth.users email confirmed by the trusted Auth service; exact normalized `student.ateneo.edu` domain (no suffix/hosted-domain-hint logic).
- Provider-managed auth.identities Google record with boolean email_verified=true and matching canonical email. User-editable metadata is ignored.
- Exactly one eligible server-controlled roster identity matching that email, unlinked or already linked to this auth UID, with active core term membership and valid dates/organization/term state. Suspended/archived members are excluded; pending membership is not approval.

For a preapproved invited/active roster row, the RPC locks/rechecks the member and links the verified auth UID, activating only that invited account. It cannot reassign a row already linked to another UID, auto-create roster entries, grant a role, or convert guests to core. A repeated call does not rewrite linkage/version. Recovery from changed email/provider identity needs a trusted custodian workflow, not browser reassignment. A Supabase Auth user may exist without organization access; no signup hook is needed for that denial boundary.

Response is either `{state:'denied'}` or `{state:'authorized',memberId,displayName,organizationId,termId,termMembershipId,expiresAt,capabilities}`. IDs/capabilities come from current database rows. Expiry is membership end; other status/provider/term changes can revoke access sooner. Invalid contexts reveal no roster details. Ambiguous identities fail closed. Existing P03 helpers now also require canonical verified school identity and **core** membership. Guests remain denied until P05 implements explicit invitations/scopes/expiry. Approval/audit workflows and delegated grant-management remain with their owning prompts; no live data activation is implied.

## Exact redirect configuration

Current allowlist in `src/features/auth/redirects.ts` and local Supabase config:

| Purpose | Exact value |
| --- | --- |
| Development application origin | http://127.0.0.1:5173 |
| Production build smoke origin | http://127.0.0.1:4173 |
| Supabase site_url | http://127.0.0.1:5173 |
| App PKCE callback allowlist | http://127.0.0.1:5173/auth/callback and http://127.0.0.1:4173/auth/callback |
| Local Google provider callback | http://127.0.0.1:54321/auth/v1/callback (verify against local Auth configuration when running) |
| Hosted Google provider callback | Use the exact organization-controlled Supabase Auth callback displayed for the approved project; no project guessed/configured here |

No wildcards, localhost alias, demo domain or unapproved production origin is allowed. A real HTTPS application origin must be explicitly added to both code and Supabase redirect allowlist when that deployment is authorized. Google redirects to **Supabase Auth**; Supabase then redirects the PKCE code to the **app** callback. Do not substitute one for the other.

## Provider setup still required

The operator needs a running local container runtime, an organization-controlled Supabase target and approved Google OAuth web client/consent configuration. School administrators may restrict access. If future guests require External consent configuration, obtain the appropriate institutional approval; the app does not change policy or send invitations.

Local config references only `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` and `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET`. Resolve them from the organization's secret store into the trusted CLI/server environment, then enable auth.external.google for the identified target. Do not put them in VITE_ variables, source, screenshots or messages. Enable no nonce-skip option. The committed Google provider stays disabled until this setup is done. No secret values were read or printed in this session; configured-reference presence checks were false and .env.local absent.

After verifying the **local** project/loopback target, start/reset only synthetic local data and run:

```powershell
pnpm exec supabase status
pnpm exec supabase test db --local supabase/tests/google_auth.test.sql
pnpm exec supabase gen types --local --schema public
```

P02 and P03 suites are historical migration-boundary tests (`pnpm test:identity`, `pnpm test:authorization`); do not run those older SQL files against the fully tightened P04 schema. Validate their boundaries in isolated local migration sets. Current local SQL check: `pnpm test:google-auth`. Catalog types include six public helpers; the private verifier is not an API/type surface.

With provider setup complete, test real school account callback, PKCE verifier/code replay failure, denied/unrostered/lookalike accounts, expired/suspended old-token requests, session refresh, account switch and local sign-out. Confirm provider-managed verified-email fields against actual Google identity output without logging tokens. Validate real JWT/PostgREST behavior and redirect rejection, plus P02/P03 compatibility gates. Do not replace these checks with mocked sessions or a service-role token. No real Google callback, auth hook, OAuth project change, JWT or hosted integration was tested here.

References: [Supabase Google PKCE](https://supabase.com/docs/guides/auth/social-login/auth-google), [provider identities](https://supabase.com/docs/guides/auth/identities), [redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls). Drive/Calendar permissions remain a separate future authorization.

P05 adds explicit external-Google invitations; see [guests.md](guests.md). Same exact PKCE callbacks, no redirect wildcard. Safe return destinations include /guest/redeem and /shared; no bearer in the return path. External consent/school-policy approval and callback remain unverified. Copy links only; no email sending. Current pnpm test:guests reruns P04 assertions on P05; test:google-auth preserves the P04 migration boundary. Types: 12 tables/10 public functions. Deployed request/parameter logs must redact invitation token bodies before activation.
