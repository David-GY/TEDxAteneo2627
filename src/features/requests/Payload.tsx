import type {FormDefinition,FormField} from './catalog/api'
import type {Choice,FormValues} from '../forms/validation'
export const money=(cents:number|null)=>cents===null?'Not provided':new Intl.NumberFormat('en-PH',{style:'currency',currency:'PHP'}).format(cents/100)
export const requestDate=(value:string|null)=>value?new Intl.DateTimeFormat('en-PH',{dateStyle:'medium',timeZone:'Asia/Manila'}).format(new Date(value)):'Not specified'
export function RequestPayload({form,values,snapshots,centavos}:{form:FormDefinition;values:FormValues;snapshots:Record<string,Choice[]>;centavos:number|null}){
 function display(f:FormField,input:FormValues,path=f.key){const v=input[f.key];if(f.storage&&f.storage!=='custom')return f.type==='currency'&&f.key==='requested_centavos'?money(centavos):'Protected workflow information is not collected by this form.';
  if(f.type==='line_items'&&Array.isArray(v))return <ol>{v.map((row,i)=><li key={i}><dl>{f.itemFields?.map(c=><div key={c.key}><dt>{c.label}</dt><dd>{display(c,row as FormValues,path+'.'+i+'.'+c.key)}</dd></div>)}</dl></li>)}</ol>;
  if(snapshots[path]?.length)return snapshots[path].map(o=>o.label).join(', ');if(v===null||v===undefined||v==='')return 'Not provided';if(typeof v==='boolean')return v?'Yes':'No';if(Array.isArray(v))return v.join(', ');return String(v)
 }
 return <dl className="request-payload">{form.fields.filter(f=>Object.hasOwn(values,f.key)||f.key==='requested_centavos'&&centavos!==null).map(f=><div key={f.key}><dt>{f.label}</dt><dd className="record-text">{display(f,values)}</dd></div>)}</dl>
}
