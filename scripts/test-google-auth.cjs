const assert = require('node:assert/strict')
const fs = require('node:fs/promises')
const {createHash} = require('node:crypto')
const {createIdentityDatabase} = require('./identity-db.cjs')
;(async()=>{
  const {db,migrations}=await createIdentityDatabase()
  try {
    await db.exec(await fs.readFile('supabase/seed.sql','utf8'))
    const result=await db.exec(await fs.readFile('supabase/tests/google_auth.test.sql','utf8'))
    const tap=result.flatMap(r=>r.rows.map(row=>row.tap).filter(Boolean))
    assert.equal(tap.length,4)
    for(let i=1;i<=3;i++) assert(tap[i].startsWith(`ok ${i} - P04_A${i}`))
    const evidence={target:'isolated in-memory PostgreSQL; authenticated subject fixtures, not real Google tokens',
      engine:(await db.query('select version()')).rows[0].version,tap,
      hashes:Object.fromEntries(await Promise.all([...migrations.map(m=>'supabase/migrations/'+m),'supabase/tests/google_auth.test.sql'].map(async f=>[f,createHash('sha256').update(await fs.readFile(f)).digest('hex')]))),
      blocked:'Docker/Supabase 17, real Google provider and JWT/PostgREST callback verification unavailable'}
    await fs.writeFile('docs/build/evidence/P04-google-auth.json',JSON.stringify(evidence,null,2)+'\n')
    console.log(JSON.stringify(evidence,null,2))
  }finally{await db.close()}
})().catch(e=>{console.error(e.code||'TEST_FAILED',e.message,e.where||'');process.exitCode=1})
