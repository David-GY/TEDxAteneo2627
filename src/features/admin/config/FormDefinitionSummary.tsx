import type {Condition,FormDefinition,FormField} from '../../requests/catalog/api'
const names:Record<string,string>={short_text:'Short answer',long_text:'Long answer',number:'Number',currency:'Protected money',date:'Date',date_time:'Date and time',single_choice:'Choose one',multi_choice:'Choose several',checkbox:'Checkbox',member:'Named member',unit:'Named committee',url:'HTTPS link',file:'Finalized files',line_items:'Repeatable rows'}
function ruleText(c:Condition|undefined,fields:FormField[],depth=0):string{
 if(!c||typeof c!=='object'||depth>4)return 'Invalid rule; validation required'
 if('conditions'in c)return Array.isArray(c.conditions)?'('+c.conditions.map(x=>ruleText(x,fields,depth+1)).join(c.op==='and'?' AND ':' OR ')+')':'Invalid rule; validation required'
 const f=fields.find(f=>f.key===c.field),op={eq:'equals',in:'matches any of',gt:'is greater than',gte:'is at least',lt:'is less than',lte:'is at most'}[c.op]
 const label=(v:unknown)=>Array.isArray(f?.options)?f.options.find(o=>o.id===v)?.label??String(v):v===true?'Yes':v===false?'No':String(v)
 return f&&op?f.label+' '+op+' '+(Array.isArray(c.value)?c.value.map(label).join(', '):label(c.value)):'Unavailable question or rule; validation required'
}
export function FormDefinitionSummary({value,previous}:{value:FormDefinition;previous?:FormDefinition}){
 const oldFields=previous?.fields.flatMap(f=>[f,...(Array.isArray(f.itemFields)?f.itemFields:[])])
 const field=(f:FormField,depth=0)=>{if(!f||typeof f!=='object'||depth>1)return <li key="invalid-child">Unsupported nested question; validation required.</li>;const old=oldFields?.find(x=>x.key===f.key),length=f.maxLength??({short_text:240,long_text:20000,url:2048}[f.type as 'short_text'|'long_text'|'url'])
  return <li key={f.key}><strong>{f.label}</strong>{previous&&!old?' · New question':null}<p>{names[f.type]??'Unsupported question type'} · {f.required?'Always required':'Optional unless a required rule matches'} · {f.classification==='confidential'?'Confidential · restricted request':'Same request access'}</p><p>{f.help}</p>
   {length!==undefined?<p>Maximum characters: {length}</p>:null}{f.min!==undefined?<p>Minimum: {f.min}</p>:null}{f.max!==undefined?<p>Maximum: {f.max}</p>:null}{f.maxItems!==undefined?<p>Maximum selections or rows: {f.maxItems}</p>:null}
   {Array.isArray(f.options)?<ol>{f.options.map(o=><li key={o.id}><span>{o.label}</span>{old&&!old.options?.some(x=>x.id===o.id)?' · New choice':null}</li>)}</ol>:null}
   {f.visibleWhen?<p>Show when: {ruleText(f.visibleWhen,value.fields)}</p>:null}{f.requiredWhen?<p>Required when: {ruleText(f.requiredWhen,value.fields)}</p>:null}
   {Array.isArray(f.itemFields)?<ul>{f.itemFields.map(child=>field(child,depth+1))}</ul>:null}
  </li>
 }
 return <><ol>{value.sections.map(s=><li key={s.key}><h4>{s.label}</h4><ul>{value.fields.filter(f=>f.section===s.key).map(f=>field(f))}</ul></li>)}</ol>{previous?.fields.some(f=>!value.fields.some(x=>x.key===f.key))?<p>Removed from future forms: {previous.fields.filter(f=>!value.fields.some(x=>x.key===f.key)).map(f=>f.label).join(', ')}. Historical requests keep these questions and answers.</p>:null}</>
}
