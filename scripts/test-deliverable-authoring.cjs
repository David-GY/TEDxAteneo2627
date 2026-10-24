const assert=require('node:assert/strict')
const fs=require('node:fs/promises')
const {createHash}=require('node:crypto')
const {createAuthoringDatabase}=require('./deliverable-authoring-db.cjs')
;(async()=>{
  const {db,migrations}=await createAuthoringDatabase()
  try{
    const output=await db.exec(await fs.readFile('supabase/tests/deliverable_commands.test.sql','utf8'))
    const tap=output.flatMap(r=>r.rows.map(row=>row.tap).filter(Boolean));assert.equal(tap.length,4)
    for(let i=1;i<=3;i++)assert(tap[i].startsWith(`ok ${i} - P09_A${i}`))
    const files=[...migrations.map(m=>'supabase/migrations/'+m),'scripts/deliverable-authoring-db.cjs','supabase/tests/deliverable_commands.test.sql']
    const evidence={target:'isolated PostgreSQL18.6/PGlite with verified-shaped synthetic subjects; no real Supabase/JWT/parallel sessions',tap,
      hashes:Object.fromEntries(await Promise.all(files.map(async f=>[f,createHash('sha256').update(await fs.readFile(f)).digest('hex')]))),
      blocked:'P02–P08 provider/human/privacy gates retained. Clean acceptance uses trusted-only synthetic non-applicability assessments, no client waiver or P29 approval.'}
    await fs.writeFile('docs/build/evidence/P09-authoring.json',JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify(evidence,null,2))
  }finally{await db.close()}
})().catch(e=>{console.error(e.code||'TEST_FAILED',e.message,e.where||'');process.exitCode=1})
