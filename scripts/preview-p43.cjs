async function createSearchPreview(port=5180){
 const p=await require('./preview-p37.cjs').createWorkflowPreview(port)
 try{
  const resources=await require('./resources-fixtures.cjs').setupResources(p)
  const guide=await resources.save({label:'Prepare event signage',body:'Read the approved signboard instructions.',alias:'signboard-guide',kind:'guide'})
  await resources.save({label:'Unpublished guidance draft',body:'Private draft text.',alias:'unpublished-secret-alias',kind:'guide',publish:false},guide.id,guide.version)
  await p.db.query('insert into public.unit_aliases values($1,$2,$3)',[p.ids.term,'old event team',p.ids.lead])
  const draft=await p.workflow.draft(p.workflow.type.id,'Arrange event signs',p.ids.outsider)
  const request=await p.workflow.call(p.ids.outsider,'submit_request',[draft.requestId,{purpose:'Private operational request narrative'},null,'2027-04-10','Arrange event signs',draft.version,require('node:crypto').randomUUID()])
  const archive=await require('./search-terms-fixture.cjs').setupSearchArchive(p,p.ids.outsider)
  return{...p,guide,archive,searchRequest:{id:draft.requestId,...request}}
 }catch(e){await p.close();throw e}
}
module.exports={createSearchPreview}
if(require.main===module)createSearchPreview().then(p=>console.log('P43 synthetic permitted search '+p.url+'/search?synthetic=associate; no provider or human acceptance')).catch(e=>{console.error(e.code,e.message);process.exitCode=1})
