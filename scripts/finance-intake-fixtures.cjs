const{randomUUID}=require('node:crypto')
async function setupFinanceIntake(p){
 const f=await require('./workflow-fixtures.cjs').setupWorkflows(p),fin=(await p.db.query("select *from public.request_types where term_id=$1 and stable_key='fin'",[p.ids.term])).rows[0],schema=(await p.db.query('select schema_json from public.form_versions where id=$1',[fin.form_version_id])).rows[0].schema_json;
 schema.fields.push({key:'evidence',section:'need',label:'Final school or receipt evidence',help:'Select only the exact finalized files. Fictional local policy; no institutional acceptance.',type:'file',classification:'confidential',required:false,maxItems:5});
 const fv=(await p.db.query("insert into public.form_versions(request_type_id,version,state,restricted,schema_json,published_at)values($1,2,'published',true,$2,statement_timestamp())returning id",[fin.id,schema])).rows[0].id;await p.db.query('update public.request_types set form_version_id=$1 where id=$2',[fv,fin.id]);
 const draft=()=>f.draft(fin.id,'PRIVATE P25 finance plan');
 const payload={schemaVersion:1,currency:'PHP',kind:'fundraising',purpose:'PRIVATE zero-cost fundraiser',fundSource:'No costs planned',beneficiaryMemberId:p.ids.viewer,relatedDeliverableId:p.ids.item,plannedOn:'2027-04-10',termsRisks:'School authorization requirements unconfirmed; synthetic local rehearsal only.',requestedTotalCentavos:'0',lines:[{description:'No financial commitment planned',quantity:'1',unitAmountCentavos:'0',totalCentavos:'0'}],pricing:{unitPriceCentavos:'10',forecastQuantity:'2',forecastRevenueCentavos:'20'}};
 const submit=(d,v=payload,key=randomUUID(),revision=false)=>f.call(p.ids.viewer,'submit_finance_request',[d.requestId,{purpose:'Restricted finance envelope'},'2027-04-10','PRIVATE P25 financial title',v,d.version,key,revision]);
 const zero=await draft(),result=await submit(zero),edit=await draft();
 await p.db.query("insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)values($1,$2,$3,$4,'member',statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days',$5)",[p.ids.org,p.ids.term,p.ids.outsider,p.ids.lead,p.ids.viewerMembership]);
 const task=await f.call(p.ids.viewer,'create_task',[p.ids.term,{title:'Shared operational task',summary:'Permitted operational details only',body:'No private case contents here',classification:'restricted',taskType:'ordinary',leadUnitId:p.ids.lead,assigneeId:p.ids.outsider,assignedUnitId:null,collaborators:[],checklist:[],dueOn:'2027-04-10',dueAt:null,parentId:p.ids.item,reason:'Synthetic P25 safe linked task'},randomUUID()]);
 return{f,fin,zero,result,edit,taskId:task.workItemId??task.id,payload,draft,submit};
}
module.exports={setupFinanceIntake}
