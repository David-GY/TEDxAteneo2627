const {randomUUID,createHash}=require('node:crypto'),{asSubject}=require('./synergy-interface-fixtures.cjs')
async function setupHandoffs(p){
 const call=(subject,name,args=[])=>asSubject(p.db,subject,tx=>tx.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')})as value`,args).then(r=>r.rows[0].value))
 const next=async()=>{const version=(await call(p.ids.viewer,'read_deliverable',[p.synergyFixture.parent])).version,proposal=await call(p.ids.viewer,'propose_synergy',[p.synergyFixture.parent,p.ids.support,{output:'Fictional agreed handoff successor '+randomUUID().slice(0,8),criteria:'Synthetic agreed next output',effort:'small',dueOn:'2027-04-15',reason:'Synthetic next agreement'},version,randomUUID()]);return(await call(p.ids.owner,'respond_to_synergy',[proposal.agreementId,'accept',1,1,p.ids.owner,null,'Explicit next-task assignment',randomUUID()])).contributionId}
 async function make(){
 const source=(await call(p.ids.viewer,'create_task',[p.ids.term,{title:'PRIVATE P17 source task '+randomUUID().slice(0,8),summary:'PRIVATE P17 summary',body:'PRIVATE P17 source body',classification:'restricted',taskType:'ordinary',leadUnitId:p.ids.lead,assigneeId:p.ids.viewer,assignedUnitId:p.ids.lead,collaborators:[],checklist:[],dueOn:'2027-04-10',dueAt:null,parentId:p.synergyFixture.parent,reason:'Synthetic handoff source'},randomUUID()])).workItemId
 const nextTask=await next();await call(p.ids.viewer,'add_task_dependency',[source,nextTask,'finish_to_start',true,1,1,'Agreed required handoff sequence',randomUUID()]);await call(p.ids.viewer,'transition_task',[source,{state:'done',reason:'Finished source',evidence:'Synthetic final source evidence'},1,randomUUID()]);
 const sourceVersion=(await call(p.ids.viewer,'read_task',[source])).version,nextVersion=(await call(p.ids.viewer,'read_task',[nextTask])).version
 const working=await call(p.ids.viewer,'save_working_link',[source,null,'https://docs.google.com/document/d/p17-source/edit','Synthetic working design','PRIVATE source notes','Export v1',sourceVersion,randomUUID()])
 const bytes=require('./file-fixtures.cjs').png(),sha=createHash('sha256').update(bytes).digest('hex'),asset=await call(p.ids.viewer,'reserve_upload',[source,'fictional-package.png','image/png',bytes.length,sha,working.assetId,1,sourceVersion,randomUUID()]);
 await p.db.transaction(async tx=>{await tx.exec('set local role service_role');await tx.query('select public.seal_upload($1,$2,$3,$4)',[asset.assetId,sha,bytes.length,'image/png'])});
 const manifest=await call(p.ids.viewer,'finalize_upload',[source,[asset.assetId],sourceVersion,randomUUID()]);
 return{source,nextTask,sourceVersion,nextVersion,workingId:working.assetId,assetId:asset.assetId,path:asset.path,manifestId:manifest.manifestId,manifestHash:manifest.sha256,bytes,sha}
 }
 return{call,make,terms:{output:'Explicitly shared P17 output',criteria:'Verify this exact finalized package',dueOn:'2027-04-12',reason:'Synthetic offered package'}}
}
module.exports={setupHandoffs}
