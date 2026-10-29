async function createWorkflowPreview(port=5178){
 const p=await require('./preview-p35.cjs').createAdoptionPreview(port)
 try{
  const workflow=await require('./workflow-fixtures.cjs').setupWorkflows(p)
  // P35 also gives the head fictional term administration. Remove that independent
  // path here so this scenario proves unit-scoped configuration and its revocation.
  await p.db.query(`update public.role_assignments a set status='revoked'where a.term_membership_id=$1 and a.scope_type='term'
   and exists(select 1 from public.role_permissions rp where rp.role_id=a.role_id and rp.capability='admin.configure')`,[workflow.reviewers[0]])
  await p.db.query(`insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)
   values($1,$2,'66666666-6666-4666-8666-666666666661','55555555-5555-4555-8555-555555555559','unit',$3,statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$4)`,[p.ids.org,p.ids.term,p.ids.support,p.ids.viewerMembership])
  const oldCase=await workflow.create([workflow.stage('review','one','approved',{label:'Review the service request'})]);await workflow.activate(oldCase)
  return{...p,workflow,oldCase,configurationType:workflow.type.id}
 }catch(e){await p.close();throw e}
}
module.exports={createWorkflowPreview}
if(require.main===module)createWorkflowPreview().then(p=>console.log('P37 synthetic workflow preview '+p.url+'/admin/config/'+p.configurationType+'; no provider or institutional authority')).catch(e=>{console.error(e.code,e.message,e.where);process.exitCode=1})
