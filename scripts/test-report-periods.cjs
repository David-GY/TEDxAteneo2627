const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),fs=require('node:fs/promises'),{asSubject}=require('./synergy-interface-fixtures.cjs')
;(async()=>{const p=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 await require('./reports-fixtures.cjs').setupReports(p)
 const {week,prior,start,end}=(await p.db.query("select app_private.report_week(statement_timestamp())::text week,(app_private.report_week(statement_timestamp())-7)::text prior,(app_private.report_week(statement_timestamp())-7)::timestamp at time zone'Asia/Manila' start,app_private.report_week(statement_timestamp())::timestamp at time zone'Asia/Manila' end")).rows[0]
 const policy=randomUUID();await p.db.query("insert into app_private.reporting_policies(id,term_id,version,enabled,retention_days,approval_reference,capture_started_at)values($1,$2,1,true,90,'Fictional eligibility interval rehearsal',$3::timestamptz-interval'1 day')",[policy,p.ids.term,start])
 await p.db.query("insert into app_private.reporting_subjects select $1,member_id,'test'from public.term_memberships where term_id=$2",[policy,p.ids.term])
 const read=async period=>asSubject(p.db,p.ids.viewer,tx=>tx.query('select public.read_reports($1,$2,null,$3)v',[p.ids.term,period,{}]).then(r=>r.rows[0].v.usage))
 const humans=[]
 for(let i=0;i<6;i++){
  const id=randomUUID();humans.push(id);await p.db.query("insert into public.members(id,organization_id,email,display_name,account_state)values($1,$2,$3,'Fictional period subject','active')",[id,p.ids.org,`period.${i}@student.ateneo.edu`])
  await p.db.query("insert into public.term_memberships(id,organization_id,term_id,member_id,status,joined_at,ends_at)values($1,$2,$3,$1,'active',$4::timestamptz+make_interval(days=>$5),statement_timestamp()+interval'30 days')",[id,p.ids.org,p.ids.term,start,i===5?3:0])
  await p.db.query("insert into app_private.reporting_subjects values($1,$2,'human')",[policy,id])
  await p.db.query("insert into app_private.usage_events(policy_id,term_id,subject_key,event_type,object_id,event_key,occurred_at)select id,term_id,encode(sha256(convert_to($2::text||salt::text,'UTF8')),'hex'),'work_viewed',$3,$4,$5::timestamptz+interval'1 hour'from app_private.reporting_policies where id=$1",[policy,id,p.ids.item,randomUUID(),start])
 }
 let usage=await read(prior);assert.equal(usage.eligible,6);assert.equal(usage.active,5,'a midweek join does not count a pre-eligibility event')
 const late=humans[5]
 const event=async moment=>p.db.query("insert into app_private.usage_events(policy_id,term_id,subject_key,event_type,object_id,event_key,occurred_at)select id,term_id,encode(sha256(convert_to($2::text||salt::text,'UTF8')),'hex'),'task_updated',$3,$4,$5 from app_private.reporting_policies where id=$1",[policy,late,p.ids.item,randomUUID(),moment])
 await event(end);assert.equal((await read(prior)).active,5,'next Monday exactly is outside the previous week')
 const lastSecond=new Date(new Date(end).getTime()-1000).toISOString();await event(lastSecond);assert.equal((await read(prior)).active,6,'Sunday final second belongs to that Manila week')
 const future=randomUUID();await p.db.query("insert into public.members(id,organization_id,email,display_name,account_state)values($1,$2,'future.period@student.ateneo.edu','Fictional future join','active')",[future,p.ids.org])
 await p.db.query("insert into public.term_memberships(id,organization_id,term_id,member_id,status,joined_at,ends_at)values($1,$2,$3,$1,'active',statement_timestamp()+interval'1 hour',statement_timestamp()+interval'30 days')",[future,p.ids.org,p.ids.term])
 usage=await read(week);assert.equal(usage.state,'available','unclassified future membership is not eligible yet and must not break current coverage');assert.equal(usage.eligible,6,'future planned joins do not inflate the current elapsed-week denominator')
 await p.db.query('delete from public.term_memberships where member_id=$1',[future])
 await assert.rejects(()=>p.db.query('delete from app_private.reporting_subjects where policy_id=$1 and member_id=$2',[policy,late]),e=>['42501','55000'].includes(e.code)) // Immutable classifier deletion must fail, never silently rewrite history.
 const disabled=randomUUID();await p.db.query("insert into app_private.reporting_policies(id,term_id,version,enabled,retention_days,approval_reference)values($1,$2,2,false,90,'Fictional capture disabled')",[disabled,p.ids.term]);assert.deepEqual(await read(week),{state:'unconfigured'})
 await fs.writeFile('docs/build/evidence/P44-periods-server.json',JSON.stringify({result:'PASS',target:'Synthetic SQL, no approved actual roster/history census',checks:['midweek joined_at clips pre-eligibility events','actual aggregate excludes next Monday and includes Sunday final second','elapsed-week denominator excludes planned future joins','unknown future classifier does not disable current coverage','disabled latest policy returns unconfigured, not a false zero'],definition:'currently approved roster states with membership interval overlap through asOf; not a reconstructed historical roster census'},null,2)+'\n');console.log('P44 late-join and actual aggregate week boundaries PASS')
 }finally{await p.db.close()}})().catch(e=>{console.error(e.code,e.message,e.stack);process.exitCode=1})
