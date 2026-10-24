const fs=require('node:fs/promises')
const assert=require('node:assert/strict')
const{createHash}=require('node:crypto')
const{createDeliverablesDatabase}=require('./deliverables-db.cjs')
;(async()=>{const{db,migrations}=await createDeliverablesDatabase({through:'20261024001300_task_reading.sql'});try{
  const output=await db.exec(await fs.readFile('supabase/tests/tasks.test.sql','utf8'));const tap=output.flatMap(r=>r.rows.map(row=>row.tap).filter(Boolean));assert.equal(tap.length,2);assert(tap[1].startsWith('ok 1 - P10_R0'))
  const files=[...migrations.map(m=>'supabase/migrations/'+m),'supabase/tests/tasks.test.sql'];const evidence={target:'isolated PGlite18.6/auth-shaped synthetic subjects; read-only P10 foundation, not task command acceptance',tap,hashes:Object.fromEntries(await Promise.all(files.map(async f=>[f,createHash('sha256').update(await fs.readFile(f)).digest('hex')]))),remaining:'P10_A1–A3 commands/assignment/progress/detail/checklist/collaborators and real provider/human verification remain pending'}
  await fs.writeFile('docs/build/evidence/P10-reading.json',JSON.stringify(evidence,null,2)+'\n');console.log('PASS P10_R0 owned task reading foundation')
}finally{await db.close()}})().catch(e=>{console.error(e.code,e.message);process.exitCode=1})
