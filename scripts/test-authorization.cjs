const assert = require('node:assert/strict')
const fs = require('node:fs/promises')
const { createHash } = require('node:crypto')
const { createIdentityDatabase } = require('./identity-db.cjs')

;(async () => {
  const { db, migrations } = await createIdentityDatabase({ through: '20261024000200_authorization.sql' })
  try {
    await db.exec(await fs.readFile('supabase/seed.sql', 'utf8'))
    const baseline = (await db.query('select count(*)::int as n from public.members')).rows[0].n
    const output = await db.exec(await fs.readFile('supabase/tests/authorization.test.sql', 'utf8'))
    const tap = output.flatMap((entry) => entry.rows.map((row) => row.tap).filter(Boolean))
    assert.equal(tap.length, 4)
    for (let i = 1; i <= 3; i++) assert(tap[i].startsWith(`ok ${i} - P03_A${i}`))
    assert.equal((await db.query('select count(*)::int as n from public.members')).rows[0].n, baseline, 'Fixtures rolled back; seed preserved')
    const evidence = {
      target: 'isolated in-memory PGlite; assertions executed under SET ROLE authenticated/anon with distinct subject claims',
      engine: (await db.query('select version()')).rows[0].version, migrations, tap,
      hashes: Object.fromEntries(await Promise.all([...migrations.map((m) => 'supabase/migrations/' + m),
        'supabase/seed.sql', 'supabase/tests/authorization.test.sql'].map(async (file) => [file, createHash('sha256').update(await fs.readFile(file)).digest('hex')]))),
      limitations: 'No real JWT/OAuth verification, PostgREST requests or Supabase PostgreSQL 17; Docker blocker carried from P02.',
    }
    await fs.writeFile('docs/build/evidence/P03-authorization.json', JSON.stringify(evidence, null, 2) + '\n')
    console.log(JSON.stringify(evidence, null, 2))
  } finally { await db.close() }
})().catch((error) => { console.error(error.code || 'TEST_FAILED', error.message, error.where || ''); process.exitCode = 1 })
