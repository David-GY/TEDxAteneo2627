const{randomUUID}=require('node:crypto'),{asSubject}=require('./synergy-interface-fixtures.cjs')
async function setupReports(p){
 const role=randomUUID();await p.db.query("insert into public.roles(id,organization_id,term_id,code,name)values($1,$2,$3,'fictional_report_reader','Fictional report reader')",[role,p.ids.org,p.ids.term]);await p.db.query("insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)values($1,$2,$3,'reports.view','term')",[p.ids.org,p.ids.term,role]);await p.db.query("insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)values($1,$2,$3,$4,'term',statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days',$3)",[p.ids.org,p.ids.term,p.ids.viewerMembership,role])
 const call=(name,args)=>asSubject(p.db,p.ids.viewer,tx=>tx.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')})value`,args).then(r=>r.rows[0].value))
 const task=await call('create_task',[p.ids.term,{title:'Confirm signage handoff',summary:'Fictional blocked work',body:'Ask the named process contact to confirm the handoff before continuing.',classification:'ordinary',taskType:'ordinary',leadUnitId:p.ids.lead,assigneeId:p.ids.viewer,assignedUnitId:p.ids.lead,collaborators:[],checklist:[{id:randomUUID(),text:'Confirm the named recipient',done:false}],dueOn:'2026-10-20',dueAt:null,parentId:null,reason:'Fictional reporting fixture'},randomUUID()])
 await call('transition_task',[task.workItemId,{state:'blocked',reason:'Waiting for the named handoff recipient',evidence:null},task.version,randomUUID()])
 // Synthetic source-data rescheduling only. Does not claim timeline negotiation UAT.
 await p.db.query("update public.work_items set due_on='2027-04-10'where id=$1",[task.workItemId])
 return{call,taskId:task.workItemId,role}
}
module.exports={setupReports}
