const assert=require('node:assert/strict'),fs=require('node:fs/promises');
(async()=>{const p=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 const f=await require('./access-fixtures.cjs').setupAccess(p);await f.admin();await f.ceiling();
 const call=(subject,name,args)=>f.call(subject,name,args),preview=(action,values,subject=p.ids.viewer)=>call(subject,'preview_access_change',[p.ids.term,action,values]);
 const publish=async(action,values,subject=p.ids.viewer,key=f.key())=>{const q=await preview(action,values,subject);return call(subject,'publish_access_change',[p.ids.term,action,values,q.version,q.fingerprint,'Fictional reviewed access change',key])};
 assert.equal((await p.db.query("select count(*)::int n from pg_proc where proname='publish_access_change'")).rows[0].n,1,'P34_A1 full authoritative mutation API exists');
 await p.db.exec(await fs.readFile('supabase/tests/access_publication.test.sql','utf8'));
 const roleValues={name:'Fictional delegated manager',scope:'unit',unitId:p.ids.lead,workId:null,permissions:[{capability:'committee.manage',scope:'unit'}]};
 const role=await publish('role_publish',roleValues);
 await p.db.query("insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)values($1,$2,$3,$4,'member',statement_timestamp()-interval'1 day',statement_timestamp()+interval'2 days','66666666-6666-4666-8666-666666666661')",[p.ids.org,p.ids.term,p.ids.outsider,p.ids.lead]);
 const dates={from:new Date().toISOString(),to:new Date(Date.now()+3600000).toISOString()};
 const values={roleId:role.id,targetMembershipId:p.ids.outsider,scope:'unit',unitId:p.ids.lead,workId:null,...dates};
 const assigned=await publish('assignment_grant',values);assert(assigned.id);
 assert.equal(await call(p.ids.outsider,'has_capability',[p.ids.term,'committee.manage',p.ids.lead]),true);
 await assert.rejects(()=>publish('assignment_grant',{...values,targetMembershipId:p.ids.viewerMembership}),e=>e.code==='42501');
 await assert.rejects(()=>publish('role_publish',{...roleValues,permissions:[{capability:'finance.review',scope:'unit'}]}),e=>e.code==='42501');
 await assert.rejects(()=>publish('role_publish',{...roleValues,permissions:[{capability:'admin.configure',scope:'term'}]}));
 const q=await preview('assignment_grant',values),retryKey=f.key();const r=await call(p.ids.viewer,'publish_access_change',[p.ids.term,'assignment_grant',values,q.version,q.fingerprint,'Fictional exact retry',retryKey]);
 assert.deepEqual(await call(p.ids.viewer,'publish_access_change',[p.ids.term,'assignment_grant',values,q.version,q.fingerprint,'Fictional exact retry',retryKey]),r);
 await assert.rejects(()=>call(p.ids.viewer,'publish_access_change',[p.ids.term,'assignment_grant',{...values,to:new Date(Date.now()+7200000).toISOString()},q.version,q.fingerprint,'Fictional exact retry',retryKey]),e=>e.code==='22023');
 await assert.rejects(()=>call(p.ids.viewer,'publish_access_change',[p.ids.term,'assignment_grant',values,q.version,q.fingerprint,'Fictional stale publication',f.key()]),e=>e.code==='40001');
 const beforeFailure=(await p.db.query('select count(*)::int n from public.roles')).rows[0].n;
 await p.db.exec("create function pg_temp.fail_access_outbox()returns trigger language plpgsql as $$begin raise exception 'fictional late access failure';end$$;create trigger fail_access_outbox before insert on public.outbox_jobs for each row execute function pg_temp.fail_access_outbox()");
 await assert.rejects(()=>publish('role_publish',{...roleValues,name:'Must roll back'}),e=>e.code==='P0001');
 assert.equal((await p.db.query('select count(*)::int n from public.roles')).rows[0].n,beforeFailure);await p.db.exec('drop trigger fail_access_outbox on public.outbox_jobs');
 const v2=await publish('role_publish',{...roleValues,familyId:role.familyId,expectedRoleVersion:1,name:'Fictional renamed manager'});assert.notEqual(v2.id,role.id);
 assert.equal((await p.db.query('select name from public.roles where id=$1',[role.id])).rows[0].name,roleValues.name);
 await assert.rejects(()=>p.db.query('update public.roles set name=$1 where id=$2',['overwrite',role.id]),e=>e.code==='55000');
 const expiry=await publish('assignment_expiry',{assignmentId:assigned.id,assignmentVersion:1,to:new Date(Date.now()+1800000).toISOString()});assert.equal(expiry.assignmentVersion,2);
 await publish('assignment_revoke',{assignmentId:assigned.id,assignmentVersion:2});
 console.log('P34_A1 real role publish/dated assignment/expiry/revoke, ceiling/self/sensitive denial, immutable revisions, stale/exact retry PASS');
 // The owner also has legacy ordinary manager authority: isolate the new lineage before testing it.
 assert.equal(await call(p.ids.outsider,'has_capability',[p.ids.term,'committee.manage',p.ids.lead]),true);
 await p.db.query("update public.role_assignments set effective_to=statement_timestamp()-interval'1 second' where id=$1",[f.source]);
 assert.equal(await call(p.ids.outsider,'has_capability',[p.ids.term,'committee.manage',p.ids.lead]),false,'Source expiry invalidates delegated authority without changing target token');
 assert.equal((await call(p.ids.outsider,'explain_my_access',[p.ids.term,null])).grants.some(g=>g.assignmentId===r.id),false);
 assert.equal((await f.synthetic()).allowsRealAccess,false);await assert.rejects(()=>f.synthetic({memberId:p.ids.owner}),e=>e.code==='22023');
 console.log('P34_A3 source expiry and own explanation/real synthetic-input rejection PASS; provider/concurrent sessions remain unverified');
 }finally{await p.db.close()}
 const c=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 const f=await require('./access-fixtures.cjs').setupAccess(c);const adminRole=await f.admin();const old=await f.custodian();
 const call=(s,n,args)=>f.call(s,n,args),preview=(action,values,subject=c.ids.viewer)=>call(subject,'preview_access_change',[c.ids.term,action,values]);
 const publish=async(action,values,subject=c.ids.viewer)=>{const q=await preview(action,values,subject);return call(subject,'publish_access_change',[c.ids.term,action,values,q.version,q.fingerprint,'Fictional verified custody change',f.key()])};
 // Independent fictional trusted ceiling provisioning; not actual institutional approval.
 for(const cap of ['admin.configure','roles.manage'])await c.db.query("insert into public.delegation_ceilings(term_id,grantor_membership_id,source_assignment_id,source_assignment_version,source_role_version,capability,scope_type,sensitive_authorized,starts_at,ends_at,approved_by,approval_reference)select a.term_id,a.term_membership_id,a.id,a.version,r.version,$2,'term',true,statement_timestamp()-interval'1 hour',statement_timestamp()+interval'2 days','66666666-6666-4666-8666-666666666661','FICTIONAL independent approval'from public.role_assignments a join public.roles r on r.id=a.role_id where a.id=$1",[old,cap]);
 await assert.rejects(()=>publish('assignment_revoke',{assignmentId:old,assignmentVersion:1},c.ids.owner),e=>e.code==='42501');
 await assert.rejects(()=>publish('assignment_revoke',{assignmentId:old,assignmentVersion:1}),e=>e.code==='42501');
 const target='66666666-6666-4666-8666-666666666661';const grant=await publish('assignment_grant',{roleId:adminRole,targetMembershipId:target,scope:'term',unitId:null,workId:null,from:new Date().toISOString(),to:new Date(Date.now()+86400000).toISOString()});
 await assert.rejects(()=>publish('assignment_revoke',{assignmentId:old,assignmentVersion:1},c.ids.owner),e=>e.message==='command_verified_replacement_required');
 const nomination=await publish('custodian_nominate',{assignmentId:grant.id,assignmentVersion:1,reference:'FICTIONAL application custody nomination'});
 await assert.rejects(()=>publish('custodian_accept',{nominationId:nomination.id,reference:'FICTIONAL wrong accepter'}));
 await publish('custodian_accept',{nominationId:nomination.id,reference:'FICTIONAL candidate acknowledgment'},c.ids.owner);
 await publish('assignment_revoke',{assignmentId:old,assignmentVersion:1},c.ids.owner);
 assert.equal((await c.db.query('select app_private.access_verified_custodian($1) ok',[grant.id])).rows[0].ok,true,'Replacement stays independently rooted after predecessor revoke');
 assert.equal(await call(c.ids.owner,'has_capability',[c.ids.term,'roles.manage',null]),true);
 console.log('P34_A2 real last-custodian removal denied, independent nomination + candidate acknowledgment + replacement/revoke PASS; actual provider custody unverified');
 }finally{await c.db.close()}
})().catch(e=>{console.error(e.code,e.message,e.where||'');process.exitCode=1});
