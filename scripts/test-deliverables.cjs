const assert=require('node:assert/strict')
const fs=require('node:fs/promises')
const {createHash}=require('node:crypto')
const {createDeliverablesDatabase}=require('./deliverables-db.cjs')
;(async()=>{
  const {db,migrations}=await createDeliverablesDatabase()
  try{
    const output=await db.exec(await fs.readFile('supabase/tests/deliverables.test.sql','utf8'))
    const tap=output.flatMap(r=>r.rows.map(row=>row.tap).filter(Boolean));assert.equal(tap.length,4)
    for(let i=1;i<=3;i++)assert(tap[i].startsWith(`ok ${i} - P08_A${i}`))
    const files=[...migrations.map(m=>'supabase/migrations/'+m),'supabase/seed.sql','scripts/deliverables-db.cjs','supabase/tests/deliverables.test.sql']
    const evidence={target:'isolated PostgreSQL18.6/PGlite, verified-shaped synthetic subjects; not Supabase17/JWT/PostgREST',tap,
      hashes:Object.fromEntries(await Promise.all(files.map(async f=>[f,createHash('sha256').update(await fs.readFile(f)).digest('hex')]))),
      blocked:'P02–P07 provider, official types, real JWT/PostgREST/Google/parallel sessions and human/privacy gates retained'}
    await fs.writeFile('docs/build/evidence/P08-deliverables.json',JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify(evidence,null,2))
  }finally{await db.close()}
})().catch(e=>{console.error(e.code||'TEST_FAILED',e.message,e.where||'');process.exitCode=1})
