const{randomUUID,createHash}=require('node:crypto'),{asSubject}=require('./synergy-interface-fixtures.cjs')
const field=(key,type,extra={})=>({key,type,section:'need',label:key.replaceAll('_',' '),help:'Fictional validation fixture; no institutional approval.',classification:'ordinary',required:false,...extra})
const definition={schemaVersion:1,sections:[{key:'need',label:'Fictional configured fields'}],fields:[
 field('need','single_choice',{label:'Does this need extra detail?',required:true,options:[{id:'yes',label:'Yes, extra detail'},{id:'no',label:'No extra detail'}]}),
 field('details','short_text',{label:'Extra detail',maxLength:100,visibleWhen:{op:'eq',field:'need',value:'yes'},requiredWhen:{op:'and',conditions:[{op:'in',field:'need',value:['yes']}]}}),
 field('body','long_text',{maxLength:1000}),field('count','number',{min:0,max:10}),field('requested_centavos','currency',{label:'Requested amount',storage:'finance',min:0,max:1000000}),field('day','date'),field('time','date_time'),
 field('tags','multi_choice',{maxItems:3,options:[{id:'a',label:'Historic label A'},{id:'b',label:'Historic label B'}]}),field('agree','checkbox',{required:true,label:'I checked these details'}),field('person','member'),field('unit','unit'),field('source','url'),field('evidence','file',{maxItems:5}),
 field('lines','line_items',{maxItems:100,label:'Evidence lines',itemFields:[field('description','short_text',{required:true,maxLength:100}),field('units_count','number',{min:0,max:20})]})]}
async function setupForms(p){
 const call=(name,args)=>asSubject(p.db,p.ids.viewer,tx=>tx.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) as value`,args).then(r=>r.rows[0].value));
 const created=await call('create_task',[p.ids.term,{title:'Fictional P20 file origin',summary:'Local form validation context',body:'PRIVATE case notes never in definitions',classification:'restricted',taskType:'ordinary',leadUnitId:null,assigneeId:p.ids.viewer,assignedUnitId:null,collaborators:[],checklist:[],dueOn:null,dueAt:null,parentId:null,reason:'Synthetic P20 fixture'},randomUUID()]),workId=created.workItemId;
 const bytes=require('./file-fixtures.cjs').png(),sha=createHash('sha256').update(bytes).digest('hex'),asset=await call('reserve_upload',[workId,'Fictional evidence.png','image/png',bytes.length,sha,null,null,created.version,randomUUID()]),fileId=asset.assetId;
 await p.db.transaction(async tx=>{await tx.exec('set local role service_role');await tx.query('select public.seal_upload($1,$2,$3,$4)',[fileId,sha,bytes.length,'image/png'])});
 p.filePreview?.bytes.set(asset.path,new Uint8Array(bytes));
 await call('finalize_upload',[workId,[fileId],created.version,randomUUID()]);
 const t=(await p.db.query("select id from public.request_types where term_id=$1 and stable_key='fin'",[p.ids.term])).rows[0].id;
 const version=(await p.db.query("insert into public.form_versions(request_type_id,version,state,restricted,published_at,schema_json)values($1,2,'published',true,statement_timestamp(),$2) returning id",[t,definition])).rows[0].id;
 await p.db.query('update public.request_types set form_version_id=$1 where id=$2',[version,t]);
 const options=await call('request_form_options',[p.ids.term,t,workId]);
 const valid={need:'yes',details:'Fictional explicit detail',body:'Multiline\nUnicode café 👋',count:2,day:'2027-04-17',time:'2027-04-17T00:00:00.000Z',tags:['b','a'],agree:true,person:p.ids.viewer,unit:p.ids.support,source:'https://school.invalid/process',evidence:[fileId],lines:[{description:'Fictional line',units_count:2}]};
 return{definition,call,typeId:t,versionId:version,workId,fileId,options,valid,centavos:12345};
}
module.exports={field,definition,setupForms}
