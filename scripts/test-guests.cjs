const assert = require('node:assert/strict')
const fs = require('node:fs/promises')
const {createHash} = require('node:crypto')
const {createIdentityDatabase} = require('./identity-db.cjs')
;(async()=>{
  const {db,migrations}=await createIdentityDatabase()
  try {
    await db.exec(await fs.readFile('supabase/seed.sql','utf8'))
    const core=await db.exec(await fs.readFile('supabase/tests/google_auth.test.sql','utf8'))
    assert.equal(core.flatMap(r=>r.rows.map(row=>row.tap).filter(Boolean)).filter(t=>t.startsWith('ok ')).length,3)
    const result=await db.exec(await fs.readFile('supabase/tests/guests.test.sql','utf8'))
    const tap=result.flatMap(r=>r.rows.map(row=>row.tap).filter(Boolean))
    assert.equal(tap.length,4)
    for(let i=1;i<=3;i++) assert(tap[i].startsWith(`ok ${i} - P05_A${i}`))
    const files=[...migrations.map(m=>'supabase/migrations/'+m),'supabase/tests/guests.test.sql','supabase/tests/google_auth.test.sql']
    const evidence={target:'isolated in-memory PostgreSQL, authenticated subject fixtures; not validated JWT/PostgREST',tap,coreRegression:'P04 Google identity assertions also passed against the full migrated schema',
      engine:(await db.query('select version()')).rows[0].version,
      hashes:Object.fromEntries(await Promise.all(files.map(async f=>[f,createHash('sha256').update(await fs.readFile(f)).digest('hex')]))),
      blocked:'Docker/Supabase PostgreSQL 17, real external Google callback and previously issued JWT transport checks'}
    await fs.writeFile('docs/build/evidence/P05-guests.json',JSON.stringify(evidence,null,2)+'\n')
    console.log(JSON.stringify(evidence,null,2))
  }finally{await db.close()}
})().catch(e=>{console.error(e.code||'TEST_FAILED',e.message,e.where||'');process.exitCode=1})
