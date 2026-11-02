async function createReportsPreview(port=5181){
 const p=await require('./preview-p43.cjs').createSearchPreview(port)
 try{
  const reports=await require('./reports-fixtures.cjs').setupReports(p)
  // Fictional receiving-head report authority only, derived by the normal
  // context RPC. Existing independent service/package checks still apply.
  await p.db.query("insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)values($1,$2,'66666666-6666-4666-8666-666666666661',$3,'term',statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$4)",[p.ids.org,p.ids.term,reports.role,p.ids.viewerMembership])
  if(!p.synergyFixture)p.synergyFixture=await require('./synergy-interface-fixtures.cjs').setupSynergyInterface(p.db,p.ids)
  const h=await require('./handoff-fixtures.cjs').setupHandoffs(p)
  const source=await h.make({classification:'ordinary',title:'Send finished venue signage'})
  const offered=await h.call(p.ids.viewer,'submit_handoff',[source.source,p.ids.owner,p.ids.support,source.manifestId,h.terms,null,source.sourceVersion,null,require('node:crypto').randomUUID()])
  return{...p,reports:{...reports,handoffId:offered.handoffId}}
 }catch(e){await p.close();throw e}
}
module.exports={createReportsPreview}
if(require.main===module)createReportsPreview().then(p=>console.log('P44 synthetic scoped reports '+p.url+'/reports; telemetry unconfigured, no provider/human acceptance')).catch(e=>{console.error(e.code,e.message,e.where||'');process.exitCode=1})
