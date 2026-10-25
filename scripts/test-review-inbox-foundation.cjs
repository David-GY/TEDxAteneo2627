const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
(async()=>{const p=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 const f=await require('./workflow-fixtures.cjs').setupWorkflows(p);
 const c=await f.create([f.stage('review','one','approved')]);await f.activate(c);
 assert.equal(await f.read(c.id,p.ids.outsider),null);
 const current=await f.read(c.id,p.ids.owner);assert(current.package);assert.equal(current.canAct,true);
 console.log('ok - P23_A1 prerequisite: unassigned associate cannot read a case; exact assigned reviewer can read its package. Queue/UI still pending.');
 await p.db.query("update public.role_assignments set status='revoked'where id=$1",[f.roles[0]]);
 assert.equal(await f.read(c.id,p.ids.owner),null);
 await assert.rejects(()=>f.call(p.ids.owner,'transition_request',[c.id,current.assignments[0].id,current.revision,current.stageKey,current.version,'approve','Open-page stale authority',null,randomUUID()]),e=>e.code==='42501');
 assert.equal((await f.read(c.id,p.ids.viewer)).effectivePaused,true);
 console.log('ok - P23_A2 prerequisite: retained open-page assignment loses read and transition authority at DB check. Browser/UI still pending.');
}finally{await p.db.close()}})().catch(e=>{console.error(e);process.exitCode=1});
