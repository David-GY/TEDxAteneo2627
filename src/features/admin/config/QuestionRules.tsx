import type {Condition,FormField} from '../../requests/catalog/api'
import {ConditionEditor} from '../workflows/ConditionEditor'
export function QuestionRules({field,earlier,index,change}:{field:FormField;earlier:FormField[];index:number;change:(next:FormField)=>void}){
 const eligible=earlier.filter(f=>(f.storage??'custom')==='custom'&&['short_text','long_text','number','single_choice','checkbox'].includes(f.type))
 const fresh=():Condition=>{const f=eligible[0];return{op:'eq',field:f.key,value:f.type==='checkbox'?true:f.type==='number'?0:f.options?.[0]?.id??''}}
 const remove=(key:'visibleWhen'|'requiredWhen')=>{const next={...field};delete next[key];change(next)}
 return <details><summary>Rules for question {index}</summary><p>Use earlier ordinary questions by name. A visibility rule hides this question when it does not match; hidden answers are not submitted. A required rule requires an answer only when it matches. Always required still takes precedence. Review and permission requirements are unchanged.</p>
  {(['visibleWhen','requiredWhen'] as const).map(key=>{const title=key==='visibleWhen'?'visibility':'required',value=field[key];return <section key={key} aria-label={title+' rule for question '+index}><h5>{key==='visibleWhen'?'Show this question when':'Require this question when'}</h5>
   {value?<><ConditionEditor value={value} fields={eligible} path={'question '+index+' '+title} change={c=>change({...field,[key]:c})}/><button type="button" className="button button--secondary" onClick={()=>remove(key)}>Remove {title} rule for question {index}</button></>:<button type="button" className="button button--secondary" disabled={!eligible.length} onClick={()=>change({...field,[key]:fresh()})}>Add {title} rule for question {index}</button>}
   {!eligible.length?<p>No eligible earlier question is available. Add or move an ordinary question before this one.</p>:null}
  </section>})}
 </details>
}
