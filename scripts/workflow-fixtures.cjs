const{randomUUID,createHash}=require('node:crypto'),{asSubject}=require('./synergy-interface-fixtures.cjs')
async function setupWorkflows(p){
 const f=await require('./request-fixtures.cjs').setupRequests(p),reviewers=['66666666-6666-4666-8666-666666666661',p.ids.outsider],roles=[];
 for(const[id,kind]of[[reviewers[0],'head'],[reviewers[1],'member']]){
  await p.db.query("insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)values($1,$2,$3,$4,$5,statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days',$6)",[p.ids.org,p.ids.term,id,p.ids.support,kind,p.ids.viewerMembership]);
  roles.push((await p.db.query("insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)values($1,$2,$3,'55555555-5555-4555-8555-555555555552','unit',$4,statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days',$5)returning id",[p.ids.org,p.ids.term,id,p.ids.support,p.ids.viewerMembership])).rows[0].id);
 }
 const type=(await p.db.query("select * from public.request_types where term_id=$1 and stable_key='general'",[p.ids.term])).rows[0],form=(await p.db.query('select schema_json from public.form_versions where id=$1',[type.form_version_id])).rows[0].schema_json;
 form.fields.push({key:'evidence',section:'need',label:'Final evidence',help:'Fictional finalized file',type:'file',classification:'ordinary',required:false,maxItems:5});
 const fv=(await p.db.query("insert into public.form_versions(request_type_id,version,state,restricted,schema_json,published_at)values($1,2,'published',false,$2,statement_timestamp())returning id",[type.id,form])).rows[0].id;await p.db.query('update public.request_types set form_version_id=$1 where id=$2',[fv,type.id]);
 const stage=(key,review='all',outcome='pending',extra={})=>({key,label:key,review,reviewers:review==='one'?[reviewers[0]]:reviewers,outcome,revisionStage:'review',entryFields:['purpose'],reminderDays:7,...extra});
 async function publish(stages){const version=(await p.db.query('select max(version)+1 n from public.workflow_versions where request_type_id=$1',[type.id])).rows[0].n,id=(await p.db.query("insert into public.workflow_versions(request_type_id,version,state,definition_json,published_at)values($1,$2,'published',$3,statement_timestamp())returning id",[type.id,version,{schemaVersion:1,stages}])).rows[0].id;await p.db.query('update public.request_types set workflow_version_id=$1 where id=$2',[id,type.id]);return id}
 const call=(subject,name,args)=>asSubject(p.db,subject,tx=>tx.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')})value`,args).then(r=>r.rows[0].value));
 const read=(id,subject=p.ids.owner)=>call(subject,'read_request_workflow',[p.ids.term,id]);
 async function create(stages=[stage('review'),stage('final','one','approved')],withFiles=false){await publish(stages);const draft=await f.create(type.id,'PRIVATE workflow case');let asset,other,manifest;
  if(withFiles){const bytes=require('./file-fixtures.cjs').png(),sha=createHash('sha256').update(bytes).digest('hex');const ids=[];
   for(const name of['chosen.png','unselected.png']){const a=await f.call('reserve_upload',[draft.requestId,name,'image/png',bytes.length,sha,null,null,draft.version,randomUUID()]);await p.db.transaction(async tx=>{await tx.exec('set local role service_role');await tx.query('select public.seal_upload($1,$2,$3,$4)',[a.assetId,sha,bytes.length,'image/png'])});p.filePreview?.bytes.set(a.path,new Uint8Array(bytes));ids.push(a.assetId)}
   await f.call('finalize_upload',[draft.requestId,ids,draft.version,randomUUID()]);[asset,other]=ids;
  }
  const result=await f.submit(draft,{purpose:'Fictional frozen review evidence',...(asset?{evidence:[asset]}:{})});manifest=(await p.db.query('select manifest_id from public.request_revisions where request_id=$1',[draft.requestId])).rows[0].manifest_id;return{id:draft.requestId,result,asset,other,manifest};
 }
 const activate=async(c,override=null,subject=p.ids.owner,key=randomUUID())=>{const r=await read(c.id,subject);return call(subject,'activate_request_workflow',[c.id,r.revision,r.stageKey,r.version,override,'Explicit fictional authority assignment',key])};
 const act=async(c,subject=p.ids.owner,action='approve',key=randomUUID(),evidence=null,view)=>{const r=view??await read(c.id,subject),a=r.assignments.find(a=>a.isMe);return call(subject,'transition_request',[c.id,a?.id??randomUUID(),r.revision,r.stageKey,r.version,action,'Reviewed this exact fictional package',evidence,key])};
 return{...f,draft:f.create,type,reviewers,roles,stage,publish,call,read,create,activate,act};
}
module.exports={setupWorkflows}
