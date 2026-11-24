import type {FormDefinition,FormField} from '../requests/catalog/api'
import {evaluateCondition,parseCentavos,type FormOptions,type FormValues} from './validation'

export function FormAnswerReview({definition,sections,values,money,options,locked,change}:{definition:FormDefinition;sections:FormDefinition['sections'];values:FormValues;money:string;options:FormOptions;locked:boolean;change:(section:string)=>void}){
 function answer(f:FormField,v:unknown):string{
  if((f.storage??'custom')!=='custom')return f.key==='requested_centavos'&&f.storage==='finance'&&parseCentavos(money)!==null?new Intl.NumberFormat('en-PH',{style:'currency',currency:'PHP'}).format(parseCentavos(money)!/100):'Managed by its protected workflow'
  if(v===undefined||v===null||v===''||Array.isArray(v)&&v.length===0)return 'Not provided'
  if(f.type==='checkbox')return v===true?'Yes':'No'
  if(['single_choice','multi_choice','member','unit','file'].includes(f.type)){const choices=f.type==='member'?options.members:f.type==='unit'?options.units:f.type==='file'?options.files:f.options??[];return(Array.isArray(v)?v:[v]).map(id=>choices.find(o=>o.id===id)?.label??'Selection unavailable').join(', ')}
  if(f.type==='date_time'&&typeof v==='string'&&Number.isFinite(Date.parse(v)))return new Date(v).toLocaleString('en-PH',{timeZone:'Asia/Manila'})+' · Asia/Manila'
  return typeof v==='string'||typeof v==='number'?String(v):'Not provided'
 }
 const visible=(f:FormField)=>!f.visibleWhen||evaluateCondition(f.visibleWhen,values)
 return <section aria-label="Review your answers"><p>Check your answers before submitting. Change a section to make corrections. Nothing is submitted until you choose the submit button.</p>{sections.map(s=><section key={s.key}><h4>{s.label}</h4><dl>{definition.fields.filter(f=>f.section===s.key&&visible(f)).map(f=><div key={f.key}><dt>{f.label}</dt><dd>{f.type==='line_items'?Array.isArray(values[f.key])&&(values[f.key]as FormValues[]).length?<ol>{(values[f.key]as FormValues[]).map((row,i)=><li key={i}><dl>{f.itemFields?.map(c=><div key={c.key}><dt>{c.label}</dt><dd>{answer(c,row[c.key])}</dd></div>)}</dl></li>)}</ol>:'Not provided':answer(f,values[f.key])}</dd></div>)}</dl><button type="button" className="button button--secondary" disabled={locked} onClick={()=>change(s.key)}>Change {s.label}</button></section>)}</section>
}
