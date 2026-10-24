const {createDeliverablesDatabase}=require('./deliverables-db.cjs')
async function createAuthoringDatabase(){
  const result=await createDeliverablesDatabase()
  try{
    await result.db.exec(`
      insert into public.roles(id,organization_id,term_id,code,name,privileged) values('55555555-5555-4555-8555-555555555559','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221','fictional_p09_manager','Fictional scoped manager',true);
      insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope) values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221','55555555-5555-4555-8555-555555555559','committee.manage','unit');
      insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)
      values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221','66666666-6666-4666-8666-666666666662','55555555-5555-4555-8555-555555555559','unit','44444444-4444-4444-8444-444444444441',statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days','66666666-6666-4666-8666-666666666661');
    `)
    return result
  }catch(error){await result.db.close();throw error}
}
module.exports={createAuthoringDatabase}
