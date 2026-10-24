const fs = require('node:fs/promises')
const path = require('node:path')
const { PGlite } = require('@electric-sql/pglite')

// No URL/path input: this harness can only create an isolated in-memory database.
async function createIdentityDatabase({ through } = {}) {
  const db = new PGlite()
  try {
    // Minimal Supabase platform contracts for SQL-only tests, not an Auth emulator.
    await db.exec(`
      create role anon nologin;
      create role authenticated nologin;
      create role service_role nologin bypassrls;
      create schema auth;
      create table auth.users(id uuid primary key, email text, email_confirmed_at timestamptz);
      create table auth.identities(id uuid primary key default gen_random_uuid(), provider_id text not null, user_id uuid references auth.users(id), provider text not null, identity_data jsonb not null, unique(provider,provider_id));
      create function auth.uid() returns uuid language sql stable as
        $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
      grant usage on schema public, auth to anon, authenticated, service_role;
      alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
      alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
    `)
    const migrations = (await fs.readdir('supabase/migrations')).filter((name) => name.endsWith('.sql') && (!through || name <= through)).sort()
    for (const file of migrations) await db.exec(await fs.readFile(path.join('supabase/migrations', file), 'utf8'))
    return { db, migrations }
  } catch (error) { await db.close(); throw error }
}

module.exports = { createIdentityDatabase }
