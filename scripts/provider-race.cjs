// Two independent authenticated HTTP identities; no claim of backend PID proof.
const fs=require('node:fs/promises'),path=require('node:path'),{randomUUID}=require('node:crypto');
const {runChecks,validateTarget}=require('./provider-verification.cjs');
const uuid=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
async function runRace(configuration,options={}){
 const receipt={schemaVersion:1,checkedAt:new Date().toISOString(),status:'blocked',releaseGate:'unverified',transport:options.fetch?'injected-test':'provider-http',databaseBackendIdentityProof:false,unverified:['backend_pid_and_lock_overlap','other_business_races','institutional_approval','full_release']};let c,profiles;
 try{c=validateTarget(configuration);profiles=['member','otherUnit'].map(name=>c.profiles.find(p=>p.case===name));if(c.race?.allowSyntheticRolePublication!==true||!uuid(c.race.unitId)||profiles.some(p=>!p)||profiles[0].subjectId===profiles[1].subjectId||profiles[0].tokenEnv===profiles[1].tokenEnv)throw Error()}catch{return{...receipt,code:'approved_two_user_synthetic_race_required'}}
 const auth=await runChecks({...c,asset:undefined,profiles},options);
 if(auth.status==='blocked'||auth.status==='failed')return{...receipt,code:'current_two_user_auth_scope_required'};
 const env=options.env??process.env,base=c.supabaseUrl.replace(/\/$/,''),fetcher=options.fetch??globalThis.fetch;
 const rpc=(name,profile,body)=>fetcher(base+'/rest/v1/rpc/'+name,{method:'POST',redirect:'error',headers:{apikey:env[c.publishableKeyEnv],authorization:'Bearer '+env[profile.tokenEnv],'content-type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 try{
  const nonce=randomUUID(),commands=[];
  for(let i=0;i<2;i++){
   const values={name:'Synthetic verification race '+nonce+' '+i,scope:'unit',unitId:c.race.unitId,workId:null,permissions:[{capability:'committee.manage',scope:'unit'}]};
   const preview=await rpc('preview_access_change',profiles[i],{p_term_id:c.termId,p_action:'role_publish',p_values:values});
   if(!preview.ok)return{...receipt,code:'both_grantor_ceilings_and_current_preview_required'};
   const q=await preview.json();if(!Number.isSafeInteger(q.version)||!/^[a-f0-9]{64}$/.test(q.fingerprint))throw Error();
   commands.push({p_term_id:c.termId,p_action:'role_publish',p_values:values,p_expected_version:q.version,p_fingerprint:q.fingerprint,p_reason:'Synthetic isolated two-user publication verification',p_request_id:randomUUID()});
  }
  if(commands[0].p_expected_version!==commands[1].p_expected_version)return{...receipt,code:'stable_common_starting_version_required'};
  const start=performance.now();
  const responses=await Promise.all(commands.map((command,i)=>rpc('publish_access_change',profiles[i],command)));
  const outcomes=await Promise.all(responses.map(async r=>({status:r.status,body:await r.json()})));
  receipt.requestWindowMs=Math.round(performance.now()-start);receipt.twoDistinctUserIdentities=true;receipt.concurrentHttpRequestsIssued=true;receipt.httpStatuses=outcomes.map(o=>o.status);
  const winner=outcomes.findIndex(o=>o.status===200&&uuid(o.body.id)&&Number.isSafeInteger(o.body.version)),loser=winner===0?1:0;
  receipt.oneWinnerOneConflict=winner!==-1&&outcomes[loser].status===409&&outcomes[loser].body.code==='40001';
  if(!receipt.oneWinnerOneConflict)return{...receipt,status:'failed',code:'unexpected_parallel_publication_outcome'};
  const retry=await rpc('publish_access_change',profiles[winner],commands[winner]);const body=retry.ok?await retry.json():null;
  receipt.exactRetry=retry.ok&&body?.id===outcomes[winner].body.id&&body?.version===outcomes[winner].body.version;
  receipt.status=!receipt.exactRetry?'failed':options.fetch?'test_only':'partial_observations';receipt.projectRef=c.projectRef;
  receipt.persistedSyntheticEffects='One unused immutable ordinary committee.manage role revision is expected; no assignment, live authority, cleanup deletion or external notification is requested.';
 }catch{receipt.status='failed';receipt.code='race_transport_or_response_unavailable'}
 return receipt;
}
module.exports={runRace};
if(require.main===module)(async()=>{
 let c=null;try{if(process.argv.length!==3)throw Error();const file=path.resolve(process.argv[2]);if(!file.startsWith(path.resolve('test-results/provider-verification')+path.sep)||!file.endsWith('.json'))throw Error();c=JSON.parse(await fs.readFile(file,'utf8'))}catch{/* No guessed target. */}
 const receipt=await runRace(c);await fs.mkdir('test-results/provider-verification',{recursive:true});await fs.writeFile('test-results/provider-verification/race-receipt.json',JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify(receipt,null,2));process.exitCode=receipt.status==='blocked'?2:receipt.status==='failed'?1:0;
})().catch(()=>{console.error('Provider race verification unavailable; no raw diagnostics printed.');process.exitCode=1});
