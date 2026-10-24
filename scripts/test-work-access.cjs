const assert=require('node:assert/strict')
const fs=require('node:fs/promises')
const {createHash}=require('node:crypto')
const {createIdentityDatabase}=require('./identity-db.cjs')
;(async()=>{
  const {db,migrations}=await createIdentityDatabase({through:'20261024001000_work_items.sql'})
  try{
    const output=await db.exec(await fs.readFile('supabase/tests/work_access.test.sql','utf8'))
    const tap=output.flatMap(r=>r.rows.map(row=>row.tap).filter(Boolean))
    assert.equal(tap.length,4)
    for(let i=1;i<=3;i++)assert(tap[i].startsWith(`ok ${i} - P07_A${i}`))
    const files=[...migrations.map(m=>'supabase/migrations/'+m),'supabase/tests/work_access.test.sql']
    const evidence={target:'isolated PGlite/auth-shaped subjects; two actors observe same version then attempt guarded updates, not true parallel Supabase sessions',
      engine:(await db.query('select version()')).rows[0].version,tap,
      hashes:Object.fromEntries(await Promise.all(files.map(async f=>[f,createHash('sha256').update(await fs.readFile(f)).digest('hex')]))),
      blocked:'Supabase PostgreSQL17/Docker, real validated JWT/PostgREST, actual parallel-session locking and human/provider gates carried from P02–P06'}
    await fs.writeFile('docs/build/evidence/P07-work-access.json',JSON.stringify(evidence,null,2)+'\n')
    console.log(JSON.stringify(evidence,null,2))
  }finally{await db.close()}
})().catch(e=>{console.error(e.code||'TEST_FAILED',e.message,e.where||'');process.exitCode=1})
