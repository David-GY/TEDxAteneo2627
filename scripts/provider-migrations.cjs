const fs=require('node:fs/promises'),{createHash}=require('node:crypto');
const projectRef='wyurosneoxfqqrrvstke';
function stripTransactions(sql){
 let mode=null,dollar='',depth=0,escape=false,plain='',start=0,begins=0,commits=0;const segments=[];
 for(let i=0;i<sql.length;i++){
  const c=sql[i],next=sql[i+1];
  if(mode==='line'){if(c==='\n')mode=null;continue}
  if(mode==='block'){if(c==='/'&&next==='*'){depth++;i++}else if(c==='*'&&next==='/'){if(--depth===0)mode=null;i++}continue}
  if(mode==='dollar'){if(sql.startsWith(dollar,i)){i+=dollar.length-1;mode=null}continue}
  if(mode==='single'){if(escape&&c==='\\'){i++;continue}if(c==="'"){if(next==="'")i++;else mode=null}continue}
  if(mode==='double'){if(c==='"'){if(next==='"')i++;else mode=null}continue}
  if(c==='-'&&next==='-'){mode='line';i++;continue}if(c==='/'&&next==='*'){mode='block';depth=1;i++;continue}
  if(c==="'"){mode='single';escape=/\b[Ee]$/.test(plain);plain+=' quoted ';continue}if(c==='"'){mode='double';plain+=' quoted ';continue}
  if(c==='$'){const m=sql.slice(i).match(/^\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$/);if(m){mode='dollar';dollar=m[0];i+=dollar.length-1;plain+=' quoted ';continue}}
  plain+=c;
  if(c===';'){
   const normalized=plain.trim().replace(/\s+/g,' ').toLowerCase();
   if(normalized==='begin;'){begins++;segments.push(sql.slice(start,i+1).replace(/\bbegin\s*;\s*$/i,''))}else if(normalized==='commit;'){commits++;segments.push(sql.slice(start,i+1).replace(/\bcommit\s*;\s*$/i,''))}
   else{if(/^(begin|commit|rollback|start transaction|end|savepoint|release|prepare transaction)\b/.test(normalized))throw Error('Unsupported top-level transaction');segments.push(sql.slice(start,i+1))}
   plain='';start=i+1;
  }
 }
 if((mode&&mode!=='line')||plain.trim()||begins!==commits||begins>1)throw Error('Unbalanced SQL or transaction wrappers');
 return{sql:segments.join('\n')+sql.slice(start)+'\n',begins,commits};
}
function buildValidation(files,{expectedMajor=17}={}){
 if(files.length!==43||![17,18].includes(expectedMajor))throw Error('Review migration inventory before preparing a bundle');
 const migrations=files.map(f=>({name:f.name,sha256:createHash('sha256').update(f.sql).digest('hex'),...stripTransactions(f.sql)}));
 const guard=`begin;\nset local lock_timeout='5s';\nset local statement_timeout='120s';\ndo $preflight$begin\n if current_setting('server_version_num')::integer/10000<>${expectedMajor} then raise exception 'Verification requires expected PostgreSQL major';end if;\n if exists(select 1 from information_schema.tables where table_schema='public'and table_type='BASE TABLE')or exists(select 1 from auth.users)or exists(select 1 from storage.buckets)or exists(select 1 from storage.objects)or to_regclass('supabase_migrations.schema_migrations')is not null then raise exception 'Verification target is not the inspected empty environment';end if;\nend$preflight$;\n`;
 const checks=`\ndo $verify$begin\n if(select count(*)from information_schema.tables where table_schema='public'and table_type='BASE TABLE')<>107 then raise exception 'Public table catalog mismatch';end if;\n if(select count(*)from information_schema.columns where table_schema='public')<>1098 then raise exception 'Public column catalog mismatch';end if;\n if(select count(*)from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.prorettype<>'trigger'::regtype)<>140 then raise exception 'Public function catalog mismatch';end if;\n if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relkind='r'and not c.relrowsecurity)then raise exception 'Exposed app table missing RLS';end if;\n if has_table_privilege('anon','public.finance_cases','select')or has_function_privilege('anon','public.publish_access_change(uuid,text,jsonb,integer,text,text,uuid)','execute')then raise exception 'Anonymous privileged interface grant';end if;\nend$verify$;\nrollback;\n`;
 const sql='-- Target '+projectRef+'; validation only; always ROLLBACK; never seed.sql.\n'+guard+migrations.map(m=>'\n-- '+m.name+' SHA256 '+m.sha256+'\n'+m.sql).join('\n')+checks;
 return{sql,manifest:{schemaVersion:1,targetProjectRef:projectRef,mode:'rollback-only',expectedPostgresMajor:expectedMajor,expectedCatalog:{tables:107,columns:1098,functions:140},migrations:migrations.map(({name,sha256,begins,commits})=>({name,sha256,removedOuterTransactions:begins+commits})),bundleSha256:createHash('sha256').update(sql).digest('hex'),normalApply:'Use the unchanged versioned migrations through the pinned CLI only after this real-target validation and a fresh empty-target check. Do not apply this rollback bundle as a committed migration or include seed.sql.'}};
}
module.exports={stripTransactions,buildValidation};
if(require.main===module)(async()=>{const names=(await fs.readdir('supabase/migrations')).filter(n=>n.endsWith('.sql')).sort(),files=await Promise.all(names.map(async name=>({name,sql:await fs.readFile('supabase/migrations/'+name,'utf8')}))),bundle=buildValidation(files);await fs.mkdir('test-results/provider-verification/migrations',{recursive:true});await fs.writeFile('test-results/provider-verification/migrations/validate.sql',bundle.sql);await fs.writeFile('docs/verification/migration-plan.json',JSON.stringify(bundle.manifest,null,2)+'\n');console.log(JSON.stringify({target:projectRef,migrations:files.length,mode:bundle.manifest.mode,bundleSha256:bundle.manifest.bundleSha256},null,2))})().catch(()=>{console.error('Migration preparation failed; inspect local source/tests. No remote request executed.');process.exitCode=1});
