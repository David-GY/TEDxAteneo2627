const {randomUUID}=require('node:crypto')
async function createAdoptionPreview(port=5178){
 const p=await require('./preview-p08.cjs').createPreview({port,authoring:true,tasks:true,financeAuthorityPreview:true,organizationPreview:true,accessPreview:true,adoptionPreview:true})
 try{
  const f=await require('./access-preview-fixtures.cjs').seedAccess(p)
  const call=f.call
  await p.db.query("update public.members set display_name='Fictional Morgan'where id=$1",[p.ids.outsider])
  const task=await call(p.ids.outsider,'create_task',[p.ids.term,{title:'Prepare your first event checklist',summary:'Fictional assigned work: review the next-step checklist.',body:'Write one question for your fictional process contact. Use Resources for help or safe practice.',classification:'restricted',taskType:'ordinary',leadUnitId:null,assigneeId:p.ids.outsider,assignedUnitId:null,collaborators:[],checklist:[{id:randomUUID(),text:'Write a question for the process contact',done:false}],dueOn:'2027-04-10',dueAt:null,parentId:null,reason:'Synthetic member first-work fixture'},randomUUID()])
  for(const [membership,type] of [[p.ids.viewerMembership,'primary_contact'],['66666666-6666-4666-8666-666666666661','backup_contact']])await p.db.query("insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)values($1,$2,$3,$4,$5,statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$6)",[p.ids.org,p.ids.term,membership,p.ids.lead,type,p.ids.viewerMembership])
  const guest='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'
  await p.db.query("insert into auth.users(id,email,email_confirmed_at)values($1,'fictional.guest@example.invalid',statement_timestamp())",[guest])
  await p.db.query("insert into auth.identities(provider_id,user_id,provider,identity_data)values($1::uuid::text,$1::uuid,'google',jsonb_build_object('email','fictional.guest@example.invalid','email_verified',true))",[guest])
  await p.db.query("insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)select a.organization_id,a.term_id,'66666666-6666-4666-8666-666666666661',a.role_id,'term',statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',a.term_membership_id from public.role_assignments a join public.role_permissions rp on rp.role_id=a.role_id and rp.capability='roles.manage'where a.term_membership_id=$1 and a.scope_type='term'limit 1",[p.ids.viewerMembership])
  const invitation=await call(p.ids.owner,'create_guest_invitation',[p.ids.term,'fictional.guest@example.invalid',randomUUID()])
  const version=(await p.db.query('select version from public.work_items where id=$1',[p.ids.item])).rows[0].version
  await call(p.ids.owner,'grant_work_access',[p.ids.item,null,null,invitation.id,'read',new Date(Date.now()+86400000).toISOString(),version,randomUUID()])
  await call(guest,'redeem_guest_invitation',[invitation.token])
  return {...p,firstTask:task.workItemId,guestSubject:guest,call}
 }catch(e){await p.close();throw e}
}
module.exports={createAdoptionPreview}
if(require.main===module)createAdoptionPreview().then(p=>console.log('P35 synthetic first-work preview '+p.url+'/tasks?synthetic=associate; fictional member/head/guest only; no real provider or human evidence')).catch(e=>{console.error(e.code,e.message);process.exitCode=1})
