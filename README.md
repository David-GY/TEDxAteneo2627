# TEDx Core Dashboard

Private core-team workspace for TEDxAteneodeManilaU. P00/P01 provide the runnable app and accessible visual shell. P02 adds a deny-by-default identity schema, fictional local seed and SQL regression checks; full Supabase-stack verification awaits Docker. No real login, connected records or business features are active. See `docs/build/STATE.md` for the current checkpoint.

## Run locally

Prerequisites: Node.js 24 LTS recommended (Node 22.12+ on its supported line also works), and pnpm **11.25.0**. Versions are pinned in package.json and pnpm-lock.yaml. The current Codex workspace bundles Node 24.22.1 and pnpm; npm is not on its PATH. Use the same pnpm version for the lockfile; do not introduce another lockfile.

```powershell
pnpm install --frozen-lockfile
pnpm dev
```

Open <http://127.0.0.1:5173/> for login, or <http://127.0.0.1:5173/preview> for the development-only shell preview. Production has no preview route. Keep a preview visible while working. The dev command binds local loopback and refuses an occupied port. Stop it with Ctrl+C. No site has been externally published/deployed.

No environment file is required. Both public settings missing produce a useful **Setup needed** page with no API calls. To configure a later step:

```powershell
Copy-Item .env.example .env.local
```

Set `VITE_SUPABASE_URL` to the project HTTPS origin (HTTP allowed on exact loopback) and `VITE_SUPABASE_PUBLISHABLE_KEY` to a new `sb_publishable_...` key. Restart Vite after changes. Configured means format-checked, **not authorized**. P04 implements PKCE/protected routes/trusted roster checks through Supabase JS; live OAuth remains pending. See `docs/integrations.md` for exact approved origins and provider setup; do not place Google secrets in client settings.

Every `VITE_` value is potentially public. Never prefix secret/service-role keys, database passwords, OAuth secrets, or refresh tokens this way. Production builds fail on partial/invalid public Supabase settings before generating new output; blank/blank is allowed for this foundation. Browser error messages never print supplied values. This is a guard against common mistakes, not a substitute for secret custody or server authorization. The parser deliberately accepts modern publishable keys, not legacy JWT keys.

## Verify

```powershell
pnpm typecheck
pnpm lint
pnpm test
pnpm build
pnpm preview
```

Production preview: <http://127.0.0.1:4173/>. `build` bundles; `typecheck` is a separate required gate. Tests exercise configuration and real routed React rendering, including missing settings, inappropriate keys, unknown paths and error-boundary recovery. They do not claim Supabase integration or human UAT. `test:watch` supports local iteration. End-to-end tooling and `test:e2e` are deferred until browser flows need a persistent suite; no placeholder successful script exists.

TypeScript is pinned to 6.0.3 because the selected TypeScript ESLint release's peer range excludes TypeScript 7. Packages were checked for compatible peer ranges before installation.

## Build sequence

- Specification: `TEDx-Core-Dashboard-Implementation-Plan.md`.
- Prompt index: `build-prompts/README.md`.
- Current state: `docs/build/STATE.md`.
- Foundation contracts: `docs/build/CONTRACTS.md`.
- Verification/checkpoint: `docs/build/steps/P00.md`.
- Shell/design contract: `DESIGN.md`; identity contracts and local database instructions: `supabase/README.md`.
- Database checks without Docker: `pnpm test:identity`, `pnpm db:types:check`. These use isolated embedded PostgreSQL, not Supabase Auth/PostgREST integration.

P02 full-stack acceptance remains pending the local container runtime; P03 adds permitted authorization policies; P04 introduces real Google login. Do not connect real finance/evaluation records to this scaffold. Production is not configured. Follow the build contract, use synthetic development data, and leave one verified checkpoint per step.

P08 adds permission-filtered deliverable reading at `/deliverables` and `/deliverables/:UUID`; see `docs/deliverables.md` and `docs/build/steps/P08.md`. Run `pnpm test:deliverables` for local SQL assertions. With Vite running, `node scripts/preview-p08.cjs` serves a labeled synthetic PostgreSQL preview at <http://127.0.0.1:5174/deliverables>; `node scripts/verify-p08.cjs` verifies a separate disposable database. These scripts simulate sign-in and do not verify Supabase/Google. Production uses real SDK RPCs and requires the documented provider/privacy gates.

P09 connects scoped deliverable create/propose/edit/reassignment and versioned acceptance commands. `pnpm test:deliverable-authoring` runs P09_A1–A3; `node scripts/preview-p09.cjs` serves the labeled synthetic authoring preview at <http://127.0.0.1:5176/deliverables>. `node scripts/verify-p09.cjs` checks disposable5177. Acceptance remains blocked for unresolved governed gates; clean local tests use trusted synthetic non-applicability assessments, never client waivers. See docs/build/steps/P09.md for evidence and carried blockers.
