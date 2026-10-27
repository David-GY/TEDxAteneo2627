// Existing isolated synthetic targets only. No login, provisioning, upload, seed or reset.
const fs=require('node:fs/promises'),path=require('node:path'),{createHash,randomUUID}=require('node:crypto');
const cases=['member','nonmember','suspended','otherUnit','activeGuest','revokedGuest','expiredGuest'];
const uuid=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const envName=v=>typeof v==='string'&&/^TEDX_VERIFY_[A-Z0-9_]{1,70}$/.test(v);
class InputFault extends Error{constructor(code){super(code);this.code=code}}
const requireInput=(test,code='approved_target_configuration_required')=>{if(!test)throw new InputFault(code)};
function validateTarget(c){
 requireInput(c&&c.schemaVersion===1&&c.environment==='isolated-synthetic'&&typeof c.targetApprovalReference==='string'&&c.targetApprovalReference.trim().length>0);
 requireInput(typeof c.projectRef==='string'&&/^[a-z0-9]{10,40}$/.test(c.projectRef));
 let url,origin;try{url=new URL(c.supabaseUrl);origin=new URL(c.appOrigin)}catch{throw new InputFault('approved_target_configuration_required')}
 requireInput(url.href===`https://${c.projectRef}.supabase.co/`&&origin.protocol==='https:'&&origin.origin===c.appOrigin&&origin.username===''&&origin.password==='');
 requireInput(uuid(c.termId)&&envName(c.publishableKeyEnv)&&Array.isArray(c.profiles)&&c.profiles.length>0&&c.profiles.length<=cases.length);
 const seen=new Set();for(const p of c.profiles){requireInput(p&&cases.includes(p.case)&&!seen.has(p.case)&&envName(p.tokenEnv)&&uuid(p.subjectId));seen.add(p.case);
  requireInput(['member','otherUnit'].includes(p.case)?uuid(p.membershipId):p.membershipId===null);
  if(['suspended','revokedGuest','expiredGuest'].includes(p.case))requireInput(Number.isFinite(Date.parse(p.scopeEndedAt))&&Date.parse(p.scopeEndedAt)<=Date.now()&&typeof p.changeEvidenceReference==='string'&&p.changeEvidenceReference.length>0,'scope_change_evidence_required');
  if(p.sharedWorkId!==undefined)requireInput(uuid(p.sharedWorkId));if(p.privateWorkId!==undefined)requireInput(uuid(p.privateWorkId));
 }
 if(c.asset)requireInput(uuid(c.asset.id)&&uuid(c.asset.workId)&&/^[a-f0-9]{64}$/.test(c.asset.sha256)&&Number.isInteger(c.asset.size)&&c.asset.size>0&&c.asset.size<=5242880&&seen.has('member'));
 return c;
}
function readToken(token,c,p){let claims;try{claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url'))}catch{throw new InputFault('current_user_jwt_required')}
 requireInput(typeof token==='string'&&token.split('.').length===3&&claims.role==='authenticated'&&claims.sub===p.subjectId&&claims.iss===c.supabaseUrl.replace(/\/$/,'')+'/auth/v1'&&Number.isFinite(claims.exp)&&claims.exp>Date.now()/1000,'current_user_jwt_required');
 if(p.scopeEndedAt)requireInput(Number.isFinite(claims.iat)&&claims.iat*1000<=Date.parse(p.scopeEndedAt),'old_valid_jwt_required');
 return token; // Decode is an input guard only; GET /auth/v1/user must authenticate it.
}
async function boundedBytes(response,limit){const parts=[];let size=0;const reader=response.body?.getReader();requireInput(reader,'download_body_required');try{for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>limit)throw new InputFault('download_size_exceeded');parts.push(value)}}finally{await reader.cancel().catch(()=>{})}return Buffer.concat(parts)}
async function runChecks(configuration,options={}){
 const checks=[],transport=options.fetch?'injected-test':'provider-http',receipt={schemaVersion:1,checkedAt:new Date().toISOString(),transport,status:'blocked',releaseGate:'unverified',checks,unverified:['real_google_pkce_callback','provider_schema_types','upload_finalize','independent_concurrent_sessions','institutional_privacy_approval','worker_operation','human_uat','restore_rehearsal']};
 let c,tokens,key;
 try{c=validateTarget(configuration);const env=options.env??process.env;key=env[c.publishableKeyEnv];requireInput(typeof key==='string'&&/^sb_publishable_[A-Za-z0-9_-]+$/.test(key),'publishable_key_reference_required');tokens=new Map(c.profiles.map(p=>{const token=env[p.tokenEnv];requireInput(typeof token==='string','user_token_references_required');return[p.case,readToken(token,c,p)]}))}catch(e){return{...receipt,code:e instanceof InputFault?e.code:'approved_target_configuration_required'}}
 receipt.projectRef=c.projectRef;receipt.targetApproval='declared reference; institutional ownership/approval not independently certified';receipt.missingCases=cases.filter(n=>!c.profiles.some(p=>p.case===n));
 const fetcher=options.fetch??globalThis.fetch,base=c.supabaseUrl.replace(/\/$/,'');
 const call=(route,token,body,origin=false)=>fetcher(base+route,{method:body===undefined?'GET':'POST',redirect:'error',headers:{apikey:key,...(token?{authorization:'Bearer '+token}:{}),...(body===undefined?{}:{'content-type':'application/json'}),...(origin?{origin:c.appOrigin}:{})},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(8000)});
 const check=(name,ok,http)=>{checks.push({check:name,result:ok?'pass':'fail',...(http===undefined?{}:{http})});return ok};
 const rpc=(name,token,body)=>call('/rest/v1/rpc/'+name,token,body);
 try{
  if(!options.fetch){const anonymous=await rpc('has_capability',null,{p_term_id:c.termId,p_capability:'workspace.read',p_unit_id:null});check('anonymous_rpc_denied',[401,403].includes(anonymous.status),anonymous.status);await anonymous.body?.cancel()}
  for(const p of c.profiles){
   const token=tokens.get(p.case),auth=await call('/auth/v1/user',token);let user=null;if(auth.ok)user=await auth.json();
   const verified=user?.id===p.subjectId&&user.identities?.some(i=>i.provider==='google'&&i.identity_data?.email_verified===true)&&(['activeGuest','revokedGuest','expiredGuest'].includes(p.case)||/^[^@\s]+@student[.]ateneo[.]edu$/i.test(user.email??''));
   if(!check(p.case+':auth_validated_by_server',verified,auth.status))continue;
   const explained=await rpc('explain_access',token,{p_term_id:c.termId});let scope=null;if(explained.ok)scope=await explained.json();
   check(p.case+':current_membership',explained.ok&&scope?.membership_id===p.membershipId&&Array.isArray(scope.grants)&&(p.membershipId!==null||scope.grants.length===0),explained.status);
   const cap=await rpc('has_capability',token,{p_term_id:c.termId,p_capability:'workspace.read',p_unit_id:null});check(p.case+':workspace_capability',cap.ok&&(await cap.json())===['member','otherUnit'].includes(p.case),cap.status);
   for(const[k,field]of [['shared','sharedWorkId'],['private','privateWorkId']])if(p[field]){const r=await rpc('can_access_work',token,{p_work_item_id:p[field],p_level:'detail'}),expected=k==='private'?p.case==='member':['member','otherUnit','activeGuest'].includes(p.case);check(p.case+':'+k+'_record_scope',r.ok&&(await r.json())===expected,r.status)}
  }
  if(c.asset){
   const owner=tokens.get('member'),metadata=await call('/rest/v1/assets?select=id,object_path,sha256,size_bytes,state&id=eq.'+c.asset.id,owner);const rows=metadata.ok?await metadata.json():null;
   const a=Array.isArray(rows)&&rows.length===1?rows[0]:null;
   const valid=metadata.ok&&a?.id===c.asset.id&&a.sha256===c.asset.sha256&&a.size_bytes===c.asset.size&&a.state==='finalized'&&typeof a.object_path==='string'&&a.object_path.split('/').every(s=>s&&s!=='.'&&s!=='..'&&!s.includes('\\')&&Array.from(s).every(c=>c.charCodeAt(0)>31));
   if(check('asset:known_finalized_fixture',valid,metadata.status)){
    const body={action:'download',workId:c.asset.workId,assetId:c.asset.id,key:randomUUID()},download=await call('/functions/v1/files',owner,body,true);
    const bytes=download.ok?await boundedBytes(download,5242880):null;
    check('asset:owner_edge_download_hash',download.ok&&bytes?.length===c.asset.size&&createHash('sha256').update(bytes??'').digest('hex')===c.asset.sha256&&download.headers.get('x-content-type-options')==='nosniff'&&/no-store/.test(download.headers.get('cache-control')??''),download.status);
    const encoded=a.object_path.split('/').map(encodeURIComponent).join('/'),prefix=a.object_path.split('/').slice(0,-1).join('/');
    for(const p of [null,...c.profiles]){const label=p?.case??'anonymous',token=p?tokens.get(p.case):null;
     for(const[op,route,data]of [['direct','/storage/v1/object/authenticated/work-private/'+encoded,undefined],['sign','/storage/v1/object/sign/work-private/'+encoded,{expiresIn:60}],['list','/storage/v1/object/list/work-private',{prefix,limit:100,offset:0}]]){
      const r=await call(route,token,data);let denied=[400,401,403,404].includes(r.status);if(op==='list'&&r.ok){const found=await r.json();denied=Array.isArray(found)&&found.length===0}else await r.body?.cancel();check(label+':storage_'+op+'_denied',denied,r.status);
     }
     if(p&&p.case!=='member'){const r=await call('/functions/v1/files',token,{...body,key:randomUUID()},true);check(label+':private_edge_download_denied',r.status===403||r.status===401,r.status);await r.body?.cancel()}
    }
   }
  }else receipt.unverified.push('storage_fixture_scope_and_bytes');
  receipt.status=checks.some(c=>c.result==='fail')?'failed':transport==='injected-test'?'test_only':'partial_observations';
 }catch{receipt.status='failed';receipt.code='transport_or_response_unavailable'}
 return receipt;
}
module.exports={validateTarget,runChecks};
if(require.main===module)(async()=>{
 let config=null;try{if(process.argv.length!==3)throw Error();const input=path.resolve(process.argv[2]),root=path.resolve('test-results/provider-verification')+path.sep;if(!input.startsWith(root)||!input.endsWith('.json'))throw Error();config=JSON.parse(await fs.readFile(input,'utf8'))}catch{/* No arbitrary path/target fallback. */}
 const receipt=await runChecks(config);await fs.mkdir('test-results/provider-verification',{recursive:true});await fs.writeFile('test-results/provider-verification/http-receipt.json',JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify(receipt,null,2));process.exitCode=receipt.status==='blocked'?2:receipt.status==='failed'?1:0;
})().catch(()=>{console.error('Provider verification unavailable; no credentials or diagnostics printed.');process.exitCode=1});
