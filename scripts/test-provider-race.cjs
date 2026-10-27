const {test}=require('node:test'),assert=require('node:assert/strict');
const {runRace}=require('./provider-race.cjs');
const base='https://abcdefghijklmnopqrst.supabase.co',a='33333333-3333-4333-8333-333333333331',b='33333333-3333-4333-8333-333333333332',unit='44444444-4444-4444-8444-444444444441',term='22222222-2222-4222-8222-222222222221';
const token=sub=>'e30.'+Buffer.from(JSON.stringify({role:'authenticated',sub,iss:base+'/auth/v1',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.fixture';
const config={schemaVersion:1,environment:'isolated-synthetic',projectRef:'abcdefghijklmnopqrst',supabaseUrl:base,appOrigin:'https://preview.example.test',targetApprovalReference:'FICTIONAL unit test',termId:term,publishableKeyEnv:'TEDX_VERIFY_PUBLISHABLE_KEY',profiles:[{case:'member',tokenEnv:'TEDX_VERIFY_A',subjectId:a,membershipId:a},{case:'otherUnit',tokenEnv:'TEDX_VERIFY_B',subjectId:b,membershipId:b}],race:{allowSyntheticRolePublication:true,unitId:unit}};
const env={TEDX_VERIFY_PUBLISHABLE_KEY:'sb_publishable_fixture',TEDX_VERIFY_A:token(a),TEDX_VERIFY_B:token(b)};
test('race refuses missing target or synthetic mutation declaration before network',async()=>{let calls=0;for(const c of [null,{...config,race:{unitId:unit}}]){const r=await runRace(c,{env,fetch:async()=>{calls++}});assert.equal(r.status,'blocked')}assert.equal(calls,0)});
test('two distinct users are issued concurrently, one stale result and exact retry are verified; fake transport stays test-only',async()=>{
 let active=0,max=0,firstKey=null;const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',requests=[];
 const r=await runRace(config,{env,fetch:async(url,o)=>{const sub=o.headers.authorization===('Bearer '+token(a))?a:b;const body=o.body?JSON.parse(o.body):null;
  if(url.endsWith('/auth/v1/user'))return Response.json({id:sub,email:'fixture@student.ateneo.edu',identities:[{provider:'google',identity_data:{email_verified:true}}]});
  if(url.endsWith('explain_access'))return Response.json({membership_id:sub,grants:[]});if(url.endsWith('has_capability'))return Response.json(true);
  if(url.endsWith('preview_access_change'))return Response.json({version:0,fingerprint:'f'.repeat(64)});
  if(url.endsWith('publish_access_change')){requests.push(body);if(body.p_request_id===firstKey)return Response.json({id,version:1});active++;max=Math.max(max,active);if(!firstKey)firstKey=body.p_request_id;await new Promise(resolve=>setImmediate(resolve));active--;return body.p_request_id===firstKey?Response.json({id,version:1}):Response.json({code:'40001'},{status:409})}
  throw Error('unexpected');
 }});
 assert.equal(max,2);assert.equal(requests.length,3);assert.equal(r.status,'test_only');assert.equal(r.oneWinnerOneConflict,true);assert.equal(r.exactRetry,true);assert.equal(r.databaseBackendIdentityProof,false);assert(!JSON.stringify(r).includes(token(a)));
});
