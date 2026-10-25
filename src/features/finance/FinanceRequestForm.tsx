import {useState} from 'react'
import {Link} from 'react-router'
import {Panel} from '../../components/Page'
import {TextField} from '../../components/TextField'
import {FormRenderer} from '../forms/FormRenderer'
import {useFormDrafts} from '../forms/Drafts'
import {validDate} from '../forms/validation'
import {calculatePlan,showPhp,type PlanDraft,type PlanKind} from './intake'
import type {FinanceIntake} from './api'
import type {useFinanceMemory} from './Memory'

export function FinanceRequestForm({data,m,refresh}:{data:FinanceIntake;m:ReturnType<typeof useFinanceMemory>;refresh:()=>void}){
 const r=data.request,d=m.fields.plan,c=calculatePlan(d),[attempted,setAttempted]=useState(false),drafts=useFormDrafts(),draftKey='finance-envelope:'+r.id+':'+r.formVersionId;
 const set=(plan:PlanDraft)=>m.change({...m.fields,plan});const error=(key:string)=>attempted||key.startsWith('lines.')?c.errors[key]:undefined;
 const input=(key:'purpose'|'fundSource'|'termsRisks'|'price'|'forecastQuantity'|'plannedOn',label:string,maxLength:number,required=true)=><TextField id={'finance-'+key} label={label} required={required} maxLength={maxLength} disabled={m.locked} value={d[key]} error={error(key)} onChange={e=>set({...d,[key]:e.target.value})}/>;
 const definition={...r.form,fields:r.form.fields.filter(f=>f.key!=='requested_centavos')};
 return <>
 <Panel title="Plan details"><p>Unsaved plan entries are kept for this account while you work and saved after a confirmed submission. Reloading the browser or signing out clears unsaved entries.</p>
 <fieldset disabled={m.locked} className="finance-fields"><legend>Private finance plan</legend>
 <TextField id="finance-title" label="Private financial title" required maxLength={240} value={m.fields.title} onChange={e=>m.change({...m.fields,title:e.target.value})}/>
 <div className="form-field"><label htmlFor="finance-kind">Plan type</label><select id="finance-kind" value={d.kind} onChange={e=>set({...d,kind:e.target.value as PlanKind})}>{(['cost','budget','expense','reimbursement','fundraising','sales']as const).map(k=><option key={k} value={k}>{k[0].toUpperCase()+k.slice(1)}</option>)}</select></div>
 {input('purpose','Plan purpose',2000)}{input('fundSource','Fund source',500)}
 <div className="form-field"><label htmlFor="finance-beneficiary">Beneficiary (required)</label><select id="finance-beneficiary" value={d.beneficiaryMemberId} onChange={e=>set({...d,beneficiaryMemberId:e.target.value})}><option value="">Choose a current member</option>{data.options?.members.map(v=><option key={v.id} value={v.id}>{v.label}</option>)}</select>{error('beneficiaryMemberId')?<p role="alert">{error('beneficiaryMemberId')}</p>:null}</div>
 <div className="form-field"><label htmlFor="finance-deliverable">Related deliverable (optional)</label><select id="finance-deliverable" value={d.relatedDeliverableId} onChange={e=>set({...d,relatedDeliverableId:e.target.value})}><option value="">No linked deliverable</option>{data.deliverables.map(v=><option key={v.id} value={v.id}>{v.label}</option>)}</select><p>Only currently permitted deliverables are listed, up to 100. A link grants no case access.</p></div>
 {input('plannedOn','Planned date (YYYY-MM-DD)',10,false)}
 <TextField id="finance-requested-on" label="Requested service date" type="date" value={m.fields.requestedOn} min="0001-01-01" max="9999-12-31" hint="A request is separate from an accepted commitment." onChange={e=>m.change({...m.fields,requestedOn:e.target.value})}/>
 {input('termsRisks','Terms, risks and school authorization requirements',4000)}
 </fieldset></Panel>
 <Panel title="Itemized requested costs"><p>PHP only. Use up to three quantity decimal places. Each line rounds half up to centavos before the total is summed.</p>
 {d.lines.map((l,i)=><fieldset key={i} disabled={m.locked} className="finance-line"><legend>Cost line {i+1}</legend><div className="finance-line-fields">
 {(['description','quantity','amount']as const).map(k=><TextField key={k} id={'finance-line-'+i+'-'+k} label={(k==='amount'?'Unit amount (PHP)':k==='quantity'?'Quantity':'Item description')+' · line '+(i+1)} required maxLength={k==='description'?500:24} inputMode={k==='description'?'text':'decimal'} value={l[k]} error={error('lines.'+i+'.'+k)} onChange={e=>set({...d,lines:d.lines.map((line,j)=>i===j?{...line,[k]:e.target.value}:line)})}/>)}</div>
 <p aria-live="polite">Line total: {c.lineTotals[i]===null?'Complete a valid quantity and unit amount.':showPhp(c.lineTotals[i]!)}</p><button type="button" className="button button--secondary" disabled={m.locked||d.lines.length===1} onClick={()=>set({...d,lines:d.lines.filter((_,j)=>j!==i)})}>Remove cost line {i+1}</button></fieldset>)}
 <button type="button" className="button button--secondary" disabled={m.locked||d.lines.length>=100} onClick={()=>set({...d,lines:[...d.lines,{description:'',quantity:'1',amount:''}]})}>Add cost line</button>
 <p role="status">Requested total: {c.total===null?'Incomplete — review line values.':showPhp(c.total)}</p>{c.errors.lines?<p role="alert">{c.errors.lines}</p>:null}
 </Panel>
 {d.kind==='sales'||d.kind==='fundraising'?<Panel title="Forecast only"><fieldset disabled={m.locked}><legend>Pricing and forecast</legend>{input('price','Unit price (PHP)',24)}{input('forecastQuantity','Forecast quantity',24)}<p role="status">Forecast revenue: {c.revenue===null?'Incomplete — review price and quantity.':showPhp(c.revenue)}</p>{c.revenue!==null&&c.total!==null?<p>Forecast margin: {(BigInt(c.revenue)-BigInt(c.total)).toString().startsWith('-')?'-'+showPhp((BigInt(c.total)-BigInt(c.revenue)).toString()):showPhp((BigInt(c.revenue)-BigInt(c.total)).toString())}</p>:null}<p>Forecasts are not actual revenue. Zero-cost fundraising still requires FIN review.</p></fieldset></Panel>:null}
 <Panel title="Requirements and submission"><p>{data.processNote}</p><p><Link to={'/requests/services/'+r.typeId}>Current service requirements</Link></p><p>Confirm the applicable school authorization and evidence requirements with FIN. Uploaded evidence and a submitted plan do not establish institutional approval.</p><p>Requested amounts and forecasts are separate from authorized ceilings and recorded actuals. Submission authorizes no commitment or payment.</p>
 <label><input type="checkbox" disabled={m.locked} checked={m.fields.ack} onChange={e=>m.change({...m.fields,ack:e.target.checked})}/>I understand this plan requires FIN review, including if its requested cost is zero.</label>
 {attempted&&(!c.payload||!m.fields.ack||!m.fields.title.trim())?<p role="alert">Review the finance fields, private title and FIN review acknowledgement before submitting.</p>:null}
 {!data.options?<p role="alert">Current form and file choices are unavailable. Refresh before submitting.</p>:<FormRenderer draftKey={draftKey} definition={definition} restricted options={data.options} mode="request" hideSave initial={{values:r.draft?.values??{},money:''}} locked={m.locked} submitDisabled={!r.canSubmit} submitLabel={r.state==='revision_draft'?'Submit revised finance plan':'Submit finance plan'} validate={async values=>{
 setAttempted(true);if(!c.payload||!m.fields.ack||!m.fields.title.trim()||m.fields.title.length>240||m.fields.requestedOn&&!validDate(m.fields.requestedOn)||d.plannedOn&&!validDate(d.plannedOn)){throw Error('Review the finance fields and dates. Entered values are kept.')}
 const result=await m.run({id:r.id,values,requestedOn:m.fields.requestedOn||null,title:m.fields.title,payload:c.payload,version:r.version,revision:r.state==='revision_draft'});if(!result){if(!m.pending)refresh();throw Error('Submission is not confirmed. Review the message above; your values are kept.')}
 drafts?.delete(draftKey);refresh();return{valid:true,errors:{},values,snapshots:{},requestedCentavos:null}
 }}/>}<p>{r.canSubmit?'Select required finalized evidence in the configured form. Upload and finalize below, then refresh to update choices.':'Submission is paused until the service and authority configuration are confirmed.'}</p>
 </Panel>
 </>
}
