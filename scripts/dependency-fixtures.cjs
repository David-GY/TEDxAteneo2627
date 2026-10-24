const {randomUUID}=require('node:crypto'),{asSubject}=require('./synergy-interface-fixtures.cjs')
async function setupDependencies(p){
 const call=(subject,name,args)=>asSubject(p.db,subject,tx=>tx.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')})as value`,args).then(r=>r.rows[0].value))
 async function task(title){return(await call(p.ids.viewer,'create_task',[p.ids.term,{title,summary:'Synthetic P16 example',body:'Private fixture notes',classification:'restricted',taskType:'ordinary',leadUnitId:p.ids.lead,assigneeId:p.ids.viewer,assignedUnitId:p.ids.lead,collaborators:[],checklist:[],dueOn:'2027-04-10',dueAt:null,parentId:null,reason:'Synthetic P16 fixture'},randomUUID()])).workItemId}
 const predecessor=await task('PRIVATE P16 predecessor'),informational=await task('Fictional informational predecessor'),proposal=await call(p.ids.viewer,'propose_synergy',[p.synergyFixture.parent,p.ids.support,{output:'Fictional dependent contribution',criteria:'Synthetic explicit output criteria',effort:'medium',dueOn:'2027-04-12',reason:'Synthetic dependency preview'},1,randomUUID()]),accepted=await call(p.ids.owner,'respond_to_synergy',[proposal.agreementId,'accept',1,1,p.ids.owner,null,'Synthetic receiving-head acceptance',randomUUID()]),successor=accepted.contributionId
 const dependency=await call(p.ids.viewer,'add_task_dependency',[predecessor,successor,'finish_to_start',true,1,1,'Synthetic required predecessor',randomUUID()])
 return{predecessor,successor,informational,dependencyId:dependency.dependencyId,call}
}
module.exports={setupDependencies}
