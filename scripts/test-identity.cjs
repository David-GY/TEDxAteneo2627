const assert = require('node:assert/strict')
const fs = require('node:fs/promises')
const { createHash } = require('node:crypto')
const { createIdentityDatabase } = require('./identity-db.cjs')

;(async () => {
  // P02 assertions intentionally verify the pre-policy migration boundary.
  const { db, migrations } = await createIdentityDatabase({ through: '20261024000100_identity.sql' })
  try {
    const seed = await fs.readFile('supabase/seed.sql', 'utf8')
    await db.exec(seed)
    const counts = async () => (await db.query(`select
      (select count(*) from public.members)::int as members,
      (select count(*) from public.org_units)::int as units,
      (select count(*) from public.role_assignments)::int as assignments`)).rows
    const first = await counts()
    await db.exec(seed)
    assert.deepEqual(await counts(), first, 'Fictional seed is repeatable without duplicates')
    assert.deepEqual(first, [{ members: 2, units: 4, assignments: 2 }])
    const result = await db.exec(await fs.readFile('supabase/tests/identity.test.sql', 'utf8'))
    const tap = result.flatMap((entry) => entry.rows.map((row) => row.tap).filter(Boolean))
    assert.equal(tap.length, 4)
    assert.equal(tap[0], '1..3')
    for (let i = 1; i <= 3; i++) assert(tap[i].startsWith(`ok ${i} - P02_A${i}`))
    // The SQL test transaction must leave no temporary policy/grant or edited fixture behind.
    assert.equal((await db.query('select count(*)::int as count from pg_policies where schemaname = $1', ['public'])).rows[0].count, 0)
    assert.equal((await db.query("select has_table_privilege('authenticated', 'public.members', 'SELECT,UPDATE') as granted")).rows[0].granted, false)
    assert.equal((await db.query("select display_name from public.members where email = 'fictional.alex@example.invalid'")).rows[0].display_name, 'Fictional Alex')
    const evidence = {
      target: 'isolated in-memory PGlite; no URL or remote connection',
      engine: (await db.query('select version()')).rows[0].version,
      migrations, seedCounts: first[0], tap,
      artifacts: Object.fromEntries(await Promise.all([
        ...migrations.map((name) => `supabase/migrations/${name}`), 'supabase/seed.sql', 'supabase/tests/identity.test.sql',
      ].map(async (file) => [file, createHash('sha256').update(await fs.readFile(file)).digest('hex')]))),
      limits: 'Minimal auth.users/auth.uid and API roles supplied by harness. Full Supabase Docker/Auth/PostgREST verification is not covered.',
    }
    await fs.writeFile('docs/build/evidence/P02-identity.json', JSON.stringify(evidence, null, 2) + '\n')
    console.log(JSON.stringify(evidence, null, 2))
  } finally { await db.close() }
})().catch((error) => { console.error(error.code || 'TEST_FAILED', error.message, error.where || ''); process.exitCode = 1 })
