import type {Condition,FormDefinition,FormField} from '../requests/catalog/api'
export type Choice={id:string;label:string}
export type FormOptions={members:Choice[];units:Choice[];files:Choice[]}
export type FormValues=Record<string,unknown>
export type Validation={valid:boolean;errors:Record<string,string>;values:FormValues|null;snapshots:Record<string,Choice[]>|null;requestedCentavos:number|null}
const kinds=['short_text','long_text','number','currency','date','date_time','single_choice','multi_choice','checkbox','member','unit','url','file','line_items']
const key=/^[a-z][a-z0-9_]{0,59}$/
const object=(x:unknown):x is Record<string,unknown>=>!!x&&typeof x==='object'&&!Array.isArray(x)
const length=(s:string)=>Array.from(s).length
const text=(x:unknown,n:number)=>typeof x==='string'&&length(x)>0&&length(x)<=n
const closed=(x:unknown,keys:string[])=>object(x)&&Object.keys(x).every(k=>keys.includes(k))
const bytes=(x:unknown)=>new TextEncoder().encode(JSON.stringify(x)).length
function conditionSchema(c:Condition,earlier:FormField[],depth=1):boolean{
 if(!closed(c,['op','field','value','conditions'])||depth>4||bytes(c)>8000)return false
 if(c.op==='and'||c.op==='or')return closed(c,['op','conditions'])&&Array.isArray(c.conditions)&&c.conditions.length>=1&&c.conditions.length<=5&&c.conditions.every(x=>conditionSchema(x,earlier,depth+1))
 if(!('field'in c)||!['eq','in','gt','gte','lt','lte'].includes(c.op)||!('value'in c)||'conditions'in c)return false
 const f=earlier.find(f=>f.key===c.field);if(!f||!['short_text','long_text','number','currency','single_choice','checkbox'].includes(f.type))return false
 if(['gt','gte','lt','lte'].includes(c.op)&&!['number','currency'].includes(f.type))return false
 if(c.op==='in'&&(!Array.isArray(c.value)||c.value.length<1||c.value.length>50))return false
 return (c.op==='in'?c.value as unknown[]:[c.value]).every(v=>['number','currency'].includes(f.type)?typeof v==='number'&&Number.isFinite(v):f.type==='checkbox'?typeof v==='boolean':text(v,200)&&(f.type!=='single_choice'||f.options?.some(o=>o.id===v)))
}
// Definitions are data. Reject unexpected syntax before any controls or conditions are evaluated.
export function validDefinition(s:FormDefinition,restricted:boolean):boolean{
 try{
 if(!closed(s,['schemaVersion','sections','fields'])||s.schemaVersion!==1||!Array.isArray(s.sections)||s.sections.length<1||s.sections.length>10||!Array.isArray(s.fields)||s.fields.length<1||s.fields.length>50||bytes(s)>100000)return false
 const sections=new Set<string>();for(const section of s.sections){if(!closed(section,['key','label'])||typeof section.key!=='string'||!key.test(section.key)||sections.has(section.key)||!text(section.label,200))return false;sections.add(section.key)}
 const fields=[...s.fields];for(const f of s.fields)if(f.type==='line_items'){if(!Array.isArray(f.itemFields)||f.itemFields.length<1||f.itemFields.length>20||f.itemFields.some(c=>c.type==='line_items'||Object.hasOwn(c,'requiredWhen')||Object.hasOwn(c,'visibleWhen')))return false;fields.push(...f.itemFields)}
 if(fields.length>50)return false;const seen=new Set<string>(),earlier:FormField[]=[]
 for(const f of fields){
  if(!closed(f,['key','section','label','help','type','classification','required','requiredWhen','visibleWhen','options','min','max','maxLength','maxItems','itemFields','storage'])||typeof f.key!=='string'||!key.test(f.key)||seen.has(f.key)||!sections.has(f.section)||!text(f.label,200)||typeof f.help!=='string'||length(f.help)>1000||typeof f.required!=='boolean'||!kinds.includes(f.type)||!['ordinary','confidential'].includes(f.classification)||f.classification==='confidential'&&!restricted||!['custom','finance','workflow'].includes(f.storage??'custom')||/(secret|password|token|case_note)/.test(f.key))return false
  if((f.type==='currency'||/(amount|centavos|ceiling|price|revenue|cost|quantity)/.test(f.key))&&f.storage!=='finance'||/(approv|decision|authorized)/.test(f.key)&&!['finance','workflow'].includes(f.storage??'custom'))return false
  if(f.maxLength!==undefined&&(!['short_text','long_text','url'].includes(f.type)||!Number.isInteger(f.maxLength)||f.maxLength<1||f.maxLength>20000))return false
  if(f.min!==undefined||f.max!==undefined){if(!['number','currency'].includes(f.type)||f.min!==undefined&&!Number.isFinite(f.min)||f.max!==undefined&&!Number.isFinite(f.max)||f.min!==undefined&&f.max!==undefined&&f.min>f.max)return false}
  if(['single_choice','multi_choice'].includes(f.type)){if(!Array.isArray(f.options)||f.options.length<1||f.options.length>50||new Set(f.options.map(o=>o.id)).size!==f.options.length||f.options.some(o=>!closed(o,['id','label'])||typeof o.id!=='string'||!key.test(o.id)||!text(o.label,200)))return false}else if(f.options!==undefined)return false
  if(['line_items','multi_choice','file'].includes(f.type)){if(!Number.isInteger(f.maxItems)||f.maxItems!<1||f.maxItems!>100)return false}else if(f.maxItems!==undefined)return false
  if(f.type!=='line_items'&&f.itemFields!==undefined||f.requiredWhen!==undefined&&!conditionSchema(f.requiredWhen,earlier)||f.visibleWhen!==undefined&&!conditionSchema(f.visibleWhen,earlier))return false
  if((f.storage??'custom')==='custom'&&s.fields.includes(f))earlier.push(f);seen.add(f.key)
 }
 return true
 }catch{return false}
}
export function evaluateCondition(c:Condition|undefined,values:FormValues,depth=1):boolean{
 if(!c||depth>4)return false
 if(c.op==='and')return c.conditions.every(x=>evaluateCondition(x,values,depth+1))
 if(c.op==='or')return c.conditions.some(x=>evaluateCondition(x,values,depth+1))
 if(!('field'in c)||!Object.hasOwn(values,c.field))return false
 const v=values[c.field];switch(c.op){case'eq':return v===c.value;case'in':return Array.isArray(c.value)&&c.value.includes(v as never);case'gt':return typeof v==='number'&&typeof c.value==='number'&&v>c.value;case'gte':return typeof v==='number'&&typeof c.value==='number'&&v>=c.value;case'lt':return typeof v==='number'&&typeof c.value==='number'&&v<c.value;case'lte':return typeof v==='number'&&typeof c.value==='number'&&v<=c.value;default:return false}
}
export function visibleValues(s:FormDefinition,values:FormValues):FormValues{const out:FormValues=Object.create(null);for(const f of s.fields){if((!f.visibleWhen||evaluateCondition(f.visibleWhen,out))&&Object.hasOwn(values,f.key))out[f.key]=values[f.key]}return out}
const empty=(v:unknown)=>v===undefined||v===null||typeof v==='string'&&/^[ \t\n\r]*$/.test(v)||Array.isArray(v)&&v.length===0
export function parseCentavos(value:string):number|null{if(!/^\d{1,13}(\.\d{1,2})?$/.test(value))return null;const [whole,part='']=value.split('.'),n=Number(whole)*100+Number(part.padEnd(2,'0'));return Number.isSafeInteger(n)?n:null}
export function validDate(value:unknown,time=false):boolean{
 if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value.slice(0,10))||Number(value.slice(0,4))<1||!Number.isFinite(Date.parse(value)))return false
 if(!time)return value.length===10&&new Date(value+'T00:00:00Z').toISOString().slice(0,10)===value
 return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/.test(value)&&new Date(value).toISOString().slice(0,10)===value.slice(0,10)&&Number(value.slice(11,13))<24&&Number(value.slice(14,16))<60&&Number(value.slice(17,19))<60
}
export function validHttpsUrl(value:string):boolean{
 if(!/^https:\/\/[A-Za-z0-9.-]+(?::[0-9]{1,5})?(?:\/[^\s]*)?$/.test(value)||value.includes('@'))return false
 const [host,port]=value.split('/')[2].split(':'),parts=host.split('.')
 if(host.length>253||port!==undefined&&(Number(port)<1||Number(port)>65535)||parts.some(p=>!/^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9])$/.test(p)))return false
 return !/^[0-9.]+$/.test(host)||parts.length===4&&parts.every(p=>Number(p)<=255&&String(Number(p))===p)
}
export function validateForm(s:FormDefinition,values:FormValues,options:FormOptions,restricted:boolean,requestedCentavos:number|null=null,complete=true):Validation{
 const errors:Record<string,string>=Object.create(null),out:FormValues=Object.create(null),snapshots:Record<string,Choice[]>=Object.create(null);let lines=0
 const fail=(k:string,code:string)=>{errors[k]??=code}
 if(!validDefinition(s,restricted))fail('$form','schema')
 else if(!object(values)||bytes(values)>100000)fail('$form','quota')
 else{
  function fields(defs:FormField[],input:FormValues,target:FormValues,prefix='',top=true){
   for(const k of Object.keys(input))if(!defs.some(f=>f.key===k))fail(prefix+k,'unknown')
   for(const f of defs){const path=prefix+f.key,v=input[f.key],visible=!f.visibleWhen||evaluateCondition(f.visibleWhen,target),required=complete&&(f.required||evaluateCondition(f.requiredWhen,target))
    if(!visible){if(Object.hasOwn(input,f.key))fail(path,'hidden');continue}
    if((f.storage??'custom')!=='custom'){
     if(Object.hasOwn(input,f.key))fail(path,'protected')
     if(top&&f.type==='currency'&&f.key==='requested_centavos'&&f.storage==='finance'){
      if(requestedCentavos===null){if(required)fail(path,'required')}
      else if(!Number.isSafeInteger(requestedCentavos)||requestedCentavos<0||f.min!==undefined&&requestedCentavos<f.min||f.max!==undefined&&requestedCentavos>f.max)fail(path,'range')
     }else if(required)fail(path,'protected')
     continue
    }
    if(empty(v)){if(required)fail(path,'required');continue}
    switch(f.type){
     case'short_text':case'long_text':case'url':
      if(typeof v!=='string'||length(v)>(f.maxLength??(f.type==='short_text'?240:f.type==='url'?2048:20000))||Array.from(v).some(c=>(c.charCodeAt(0)<32||c.charCodeAt(0)===127)&&!['\n','\r','\t'].includes(c)))fail(path,'type')
      else if(f.type==='url'&&!validHttpsUrl(v))fail(path,'type');break
     case'number':if(typeof v!=='number'||!Number.isFinite(v))fail(path,'type');else if(Math.abs(v)>Number.MAX_SAFE_INTEGER||f.min!==undefined&&v<f.min||f.max!==undefined&&v>f.max)fail(path,'range');break
     case'checkbox':if(typeof v!=='boolean')fail(path,'type');else if(required&&v!==true)fail(path,'required');break
     case'date':case'date_time':if(!validDate(v,f.type==='date_time'))fail(path,'type');break
     case'single_choice':if(typeof v!=='string'||!f.options?.some(o=>o.id===v))fail(path,'choice');else snapshots[path]=f.options.filter(o=>o.id===v);break
     case'multi_choice':if(!Array.isArray(v)||v.length>f.maxItems!||new Set(v).size!==v.length||!v.every(x=>typeof x==='string'&&f.options?.some(o=>o.id===x)))fail(path,'choice');else snapshots[path]=v.map(id=>f.options!.find(o=>o.id===id)!);break
     case'member':case'unit':{const choices=f.type==='member'?options.members:options.units;if(typeof v!=='string'||!choices.some(o=>o.id===v))fail(path,'ineligible');else snapshots[path]=choices.filter(o=>o.id===v);break}
     case'file':if(!Array.isArray(v)||v.length>f.maxItems!||new Set(v).size!==v.length||!v.every(x=>typeof x==='string'&&options.files.some(o=>o.id===x)))fail(path,'ineligible');else snapshots[path]=v.map(id=>options.files.find(o=>o.id===id)!);break
     case'line_items':if(!Array.isArray(v)||v.length>f.maxItems!||(lines+=Array.isArray(v)?v.length:0)>100)fail(path,'quota');else{const rows:FormValues[]=[];v.forEach((row,i)=>{if(!object(row))fail(path+'.'+i,'type');else{const targetRow:FormValues=Object.create(null);fields(f.itemFields!,row,targetRow,path+'.'+i+'.',false);rows.push(targetRow)}});target[f.key]=rows}break
     default:fail(path,'protected')
    }
    if(!errors[path]&&f.type!=='line_items')target[f.key]=v
   }
  }
  fields(s.fields,values,out)
  if(requestedCentavos!==null&&!s.fields.some(f=>f.key==='requested_centavos'&&f.type==='currency'&&f.storage==='finance'&&(!f.visibleWhen||evaluateCondition(f.visibleWhen,out))))fail('requested_centavos','protected')
 }
 const valid=Object.keys(errors).length===0;return{valid,errors,values:valid?out:null,snapshots:valid?snapshots:null,requestedCentavos:valid?requestedCentavos:null}
}
