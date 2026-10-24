const fs=require('node:fs/promises')
const {createIdentityDatabase}=require('./identity-db.cjs')
const ids={org:'11111111-1111-4111-8111-111111111111',term:'22222222-2222-4222-8222-222222222221',owner:'33333333-3333-4333-8333-333333333331',viewer:'33333333-3333-4333-8333-333333333332',outsider:'33333333-3333-4333-8333-333333333333',item:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',hidden:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa9',lead:'44444444-4444-4444-8444-444444444441',support:'44444444-4444-4444-8444-444444444442',privateUnit:'44444444-4444-4444-8444-444444444443',viewerMembership:'66666666-6666-4666-8666-666666666662'}
// No URL/path argument: these identities and data can only exist in an isolated memory database.
async function createDeliverablesDatabase(){
  const {db,migrations}=await createIdentityDatabase()
  try{
    await db.exec(await fs.readFile('supabase/seed.sql','utf8'))
    await db.query(`insert into auth.users(id,email,email_confirmed_at) values($1,'fictional.alex@student.ateneo.edu',statement_timestamp()),($2,'fictional.river@student.ateneo.edu',statement_timestamp()),($3,'fictional.observer@student.ateneo.edu',statement_timestamp())`,[ids.owner,ids.viewer,ids.outsider])
    await db.query(`insert into auth.identities(provider_id,user_id,provider,identity_data) select id::text,id,'google',jsonb_build_object('email',email,'email_verified',true) from auth.users`)
    await db.query(`update public.members set email=(select email from auth.users where id=members.id),auth_user_id=id,account_state='active' where id in($1,$2)`,[ids.owner,ids.viewer])
    await db.query(`insert into public.members(id,organization_id,auth_user_id,email,display_name,account_state) values($1,$2,$1,'fictional.observer@student.ateneo.edu','Fictional observer','active')`,[ids.outsider,ids.org])
    await db.query(`insert into public.term_memberships(id,organization_id,term_id,member_id,status,joined_at,ends_at) values($1,$2,$3,$1,'active',statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days')`,[ids.outsider,ids.org,ids.term])
    await db.query(`insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by) values($1,$2,$3,'55555555-5555-4555-8555-555555555551','term',statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days','66666666-6666-4666-8666-666666666661'),($1,$2,$4,'55555555-5555-4555-8555-555555555551','term',statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days','66666666-6666-4666-8666-666666666661')`,[ids.org,ids.term,ids.viewerMembership,ids.outsider])
    await db.query(`insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by) values($1,$2,$3,$4,'member',statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days','66666666-6666-4666-8666-666666666661')`,[ids.org,ids.term,ids.viewerMembership,ids.lead])
    await db.query(`insert into public.record_grants(organization_id,term_id,work_item_id,member_id,grant_kind,expires_at,grantor_id) values($1,$2,$3,$4,'read',statement_timestamp()+interval'7 days','66666666-6666-4666-8666-666666666661')`,[ids.org,ids.term,ids.item,ids.viewer])
    await db.transaction(async tx=>{
      await tx.query(`insert into public.work_items(id,organization_id,term_id,kind,title,safe_summary,classification,owner_member_id,owner_display_name,lead_unit_id,status_id) select $1,organization_id,term_id,kind,'PRIVATE OUTPUT','PRIVATE SUMMARY','restricted',owner_member_id,owner_display_name,$2,status_id from public.work_items where id=$3`,[ids.hidden,ids.privateUnit,ids.item])
      await tx.query(`insert into public.deliverables(work_item_id,organization_id,term_id,phase_key,outcome,body) values($1,$2,$3,'PRIVATE PHASE','PRIVATE OUTCOME','PRIVATE BODY')`,[ids.hidden,ids.org,ids.term])
    })
    return {db,migrations,ids}
  }catch(error){await db.close();throw error}
}
module.exports={createDeliverablesDatabase,ids}
