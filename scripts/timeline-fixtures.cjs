const{randomUUID}=require('node:crypto')
async function setupTimeline(p){
 const call=async(name,args,subject=p.ids.viewer)=>require('./synergy-interface-fixtures.cjs').asSubject(p.db,subject,async tx=>(await tx.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) as value`,args)).rows[0].value)
 const task=async(title,dueOn,start)=>{const made=await call('create_task',[p.ids.term,{title,summary:'Fictional committee timeline example',body:'Fictional working notes',classification:'restricted',taskType:'ordinary',leadUnitId:p.ids.lead,assigneeId:p.ids.viewer,assignedUnitId:p.ids.lead,collaborators:[],checklist:[],dueOn,dueAt:null,parentId:null,reason:'Fictional timeline fixture'},randomUUID()]);if(start)await call('update_work_schedule',[made.workItemId,start,1,randomUUID()]);return made.workItemId}
 const predecessor=await task('Fictional venue plan','2027-04-08','2027-04-01'),successor=await task('Fictional room preparation','2027-04-15','2027-04-09'),deadline=await task('Fictional print deadline','2027-04-17',null),startOnly=await task('Fictional owner briefing',null,'2027-04-05'),missing=await task('Fictional unscheduled research',null,null),overdue=await task('Fictional overdue follow-up','2026-10-20',null)
 await call('add_task_dependency',[predecessor,successor,'finish_to_start',true,2,2,'Required fictional sequence',randomUUID()])
 await call('add_task_dependency',[predecessor,deadline,'informational',false,(await call('read_task',[predecessor])).version,1,'Fictional context link',randomUUID()])
 const parent=p.synergyFixture.parent;await call('update_work_schedule',[parent,'2027-04-01',1,randomUUID()])
 const proposal=await call('propose_synergy',[parent,p.ids.support,{output:'Fictional committee design contribution',criteria:'Fictional reviewed design output',effort:'small',dueOn:'2027-04-14',reason:'Fictional timeline shared work'},2,randomUUID()])
 const accepted=await call('respond_to_synergy',[proposal.agreementId,'accept',1,1,p.ids.owner,null,'Explicit fictional owner',randomUUID()],p.ids.owner)
 return{call,predecessor,successor,deadline,startOnly,missing,overdue,parent,contribution:accepted.contributionId}
}
module.exports={setupTimeline}
