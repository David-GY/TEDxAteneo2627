# TEDx Core Dashboard

React and TypeScript webapp with Supabase database migrations and Edge Functions. This branch contains the application source, public assets, backend source, and build configuration.

## Local development

Use Node.js 24 LTS and pnpm 11.25.0.

```sh
pnpm install --frozen-lockfile
pnpm dev
```

Open http://127.0.0.1:5173/. With no environment settings, the app displays its Setup needed screen. Copy `.env.example` to `.env.local` and supply the public Supabase settings for an approved development project. Never put service-role keys, OAuth secrets, database passwords, or other server credentials in `VITE_` settings.

## Check and build

```sh
pnpm typecheck
pnpm typecheck:files
pnpm lint
pnpm build
pnpm preview
```

The static frontend is generated in `dist/`. For an approved Pages environment, set the exact HTTPS frontend origin and public Supabase configuration, then run `pnpm build:pages`. Serve the generated security headers and provide SPA fallback routing for application links.

## Backend

`supabase/migrations/` contains 95 ordered database migrations. `supabase/functions/` contains the Edge Functions, and `supabase/config.toml` contains the local Supabase configuration. The pinned Supabase CLI is available through `pnpm exec supabase`. Inspect the target and migration ledger before applying changes. Synthetic development seeds and audit/test fixtures are excluded from this branch. Configure function secrets in the approved server environment. Optional integrations remain disabled until configured and authorized.

## Deployment status

This is a locally verified candidate. Uploading source to GitHub does not authorize live deployment. The existing operational release hold remains in effect pending approved production accounts and configuration, hosted provider verification, representative human acceptance, and recovery/custody approval.
