const assert = require('node:assert/strict')
const fs = require('node:fs/promises')
const { createHash } = require('node:crypto')
const { createIdentityDatabase } = require('./identity-db.cjs')
;(async () => {
  const { db, migrations } = await createIdentityDatabase()
  try {
    const output = await db.exec(await fs.readFile('supabase/tests/directory.test.sql', 'utf8'))
    const tap = output.flatMap(r => r.rows.map(row => row.tap).filter(Boolean))
    assert.equal(tap.length, 4)
    for (let i = 1; i <= 3; i++) assert(tap[i].startsWith(`ok ${i} - P06_A${i}`))
    const guestOutput = await db.exec(await fs.readFile('supabase/tests/guest_contacts.test.sql', 'utf8'))
    const guestTap = guestOutput.flatMap(r => r.rows.map(row => row.tap).filter(Boolean))
    assert.equal(guestTap.length, 4)
    for (let i = 1; i <= 3; i++) assert(guestTap[i].startsWith(`ok ${i} - P06_G${i}`))
    const files = [...migrations.map(m => 'supabase/migrations/' + m), 'supabase/tests/directory.test.sql', 'supabase/tests/guest_contacts.test.sql']
    const evidence = { target: 'isolated PGlite/auth-shaped subjects; no real JWT/PostgREST', engine: (await db.query('select version()')).rows[0].version, tap, guestTap,
      hashes: Object.fromEntries(await Promise.all(files.map(async f => [f, createHash('sha256').update(await fs.readFile(f)).digest('hex')]))),
      remaining: 'Real Supabase17/JWT/PostgREST/Google and human verification; all P02–P05 external blockers. P07 exact-record contacts are covered separately by test:work-access when that migration is present.' }
    await fs.writeFile('docs/build/evidence/P06-directory.json', JSON.stringify(evidence, null, 2) + '\n')
    console.log(JSON.stringify(evidence, null, 2))
  } finally { await db.close() }
})().catch(e => { console.error(e.code || 'TEST_FAILED', e.message, e.where || ''); process.exitCode = 1 })
