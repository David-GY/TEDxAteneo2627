import {ScheduleEditor} from '../timeline/ScheduleEditor'
import type {TimelineApi} from '../timeline/api'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { Panel } from '../../components/Page'
import { LoadingState } from '../../components/FeedbackState'
import { TextField } from '../../components/TextField'
import type { AuthoringCommand, AuthoringContext, DeliverableAction, DeliverableCommands, DeliverableData } from './commands'
const labels:Record<DeliverableAction,string>={approve_proposal:'Approve proposed commitment',start:'Start work',submit:'Submit for acceptance',accept:'Accept deliverable',revise:'Return to draft',cancel:'Cancel deliverable'}
export function DeliverableEditor({api,termId,id,onSaved,onReload,timeline,onPendingChange}:{timeline?:TimelineApi;onPendingChange?:(pending:boolean)=>void;api:DeliverableCommands;termId:string;id?:string;onSaved:(id:string)=>void;onReload?:()=>void}){
  const [context,setContext]=useState<AuthoringContext|null|undefined>(undefined)
  const [error,setError]=useState('');const [busy,setBusy]=useState(false);const [uncertain,setUncertain]=useState(false)
  const [reload,setReload]=useState(0);const [notice,setNotice]=useState('')
  const [lead,setLead]=useState('');const [propose,setPropose]=useState(true)
  const [action,setAction]=useState<DeliverableAction|'none'>('none')
  const[schedulePending,setSchedulePending]=useState(false)
  useEffect(()=>{onPendingChange?.(schedulePending)},[schedulePending,onPendingChange])
  const pending=useRef<{input:AuthoringCommand;key:string}|null>(null)
  useEffect(()=>{let active=true;void api.read(termId,id).then(c=>{if(active){setContext(c);setLead(c?.data?.leadUnitId??c?.units[0]?.id??'');setPropose(!c?.units[0]?.canManage);setError('')}}).catch(()=>{if(active){setError('Authoring access could not load. Reload to check access.');setContext(undefined)}});return()=>{active=false}},[api,termId,id,reload])
  function refresh(reloadOverview=true){setContext(undefined);pending.current=null;setUncertain(false);setAction('none');setError('');setReload(reload+1);if(reloadOverview)onReload?.()}
  async function run(input:AuthoringCommand){
    const request=pending.current??{input,key:crypto.randomUUID()};pending.current=request;setBusy(true);setError('');setNotice('')
    const result=await api.execute(request.input,request.key);setBusy(false)
    if(!result.ok){setError(result.error.message);setUncertain(result.error.retryable);if(!result.error.retryable)pending.current=null;return}
    pending.current=null;setUncertain(false);setNotice('Saved. The database confirmed this change.');onSaved(result.value.workItemId);refresh(false)
  }
  function save(event:FormEvent<HTMLFormElement>){
    event.preventDefault();if(!context)return
    const fields=new FormData(event.currentTarget);const text=(k:string)=>String(fields.get(k)??'')
    const proposal=!context.units.find(u=>u.id===lead)?.canManage||propose
    const values:DeliverableData={title:text('title'),summary:text('summary'),body:text('body'),ownerId:id?text('ownerId'):proposal?context.memberId:text('ownerId'),leadUnitId:lead,
      phase:text('phase'),outcome:text('outcome'),criteria:text('criteria'),dueOn:text('dueOn')||null,dueAt:context.data?.dueAt??null,classification:(context.data?.classification??text('classification')) as DeliverableData['classification'],reason:text('reason')}
    void run(id?{command:'update',id,data:values,version:context.version!}:{command:'create',termId,data:values,propose:proposal})
  }
  function transition(event:FormEvent<HTMLFormElement>){event.preventDefault();if(!context||!id)return;const fields=new FormData(event.currentTarget);const selected=String(fields.get('action')) as DeliverableAction;void run({command:'transition',id,action:selected,reason:String(fields.get('reason')??''),evidence:String(fields.get('evidence')??'')||null,version:context.version!,criteriaRevision:fields.get('confirmed')?context.criteriaRevision??undefined:undefined})}
  if(context===null)return null
  const d=context?.data;const canManage=context?.units.find(u=>u.id===lead)?.canManage
  const content=<>
    {error?<p role="alert">{error}</p>:null}{notice?<p role="status">{notice}</p>:null}
    <button className="button button--secondary" data-discard-edits disabled={busy||uncertain||schedulePending} onClick={()=>refresh()}>Reload latest (discard unsaved edits)</button>
    {uncertain?<button className="button" disabled={busy||schedulePending} onClick={()=>pending.current&&void run(pending.current.input)}>Retry same request</button>:null}
    {context===undefined?!error?<LoadingState title="Checking authoring access"/>:null:<>
      {context.queue.length?<div><h3>Owners needing reassignment</h3><ul>{context.queue.map(q=><li key={q.id}><Link to={'/deliverables/'+q.id}>{q.title}</Link></li>)}</ul></div>:null}
      {id?<p>Workflow: {context.state?.replaceAll('_',' ')} · Version {context.version}. Use current readiness checks for final acceptance.</p>:<p>Members propose themselves as owners. A configured committee manager must approve the event commitment.</p>}
      {!id||context.editable?<form key={reload+':'+context.version} onSubmit={save} className="deliverable-editor">
        <fieldset disabled={busy||uncertain||schedulePending}>
          <TextField id="deliverable-title" name="title" label="Title" required maxLength={240} defaultValue={d?.title}/>
          <TextField id="deliverable-summary" name="summary" label="Safe summary" maxLength={2000} defaultValue={d?.summary} hint="Visible to everyone permitted to read this summary."/>
          <div className="form-field"><label htmlFor="deliverable-lead">Lead committee (required)</label><select id="deliverable-lead" name="leadUnitId" required value={lead} disabled={!!id&&!context.manager} onChange={e=>setLead(e.target.value)}>{context.units.map(u=><option key={u.id} value={u.id}>{u.name}</option>)}</select></div>
          {!id&&canManage?<label className="editor-check"><input type="checkbox" checked={propose} onChange={e=>setPropose(e.target.checked)}/>Submit as my proposal</label>:null}
          <div className="form-field"><label htmlFor="deliverable-owner">Accountable owner (required)</label><select id="deliverable-owner" name="ownerId" required defaultValue={d?.ownerId??context.memberId} disabled={!!id&&!context.manager||!id&&(!canManage||propose)}>{d&&!context.owners.some(o=>o.id===d.ownerId)?<option value={d.ownerId}>Current owner not in the active choices</option>:null}{context.owners.map(o=><option key={o.id} value={o.id}>{o.name}</option>)}</select></div>
          {id&&!context.manager?<input type="hidden" name="ownerId" value={d?.ownerId}/>:null}
          <TextField id="deliverable-phase" name="phase" label="Phase" required maxLength={80} defaultValue={d?.phase}/>
          <TextField id="deliverable-due" name="dueOn" type="date" label="Target date · Manila" required={!d?.dueAt} disabled={!!d?.dueAt} defaultValue={d?.dueOn??''} hint={d?.dueAt?'This timestamp deadline is preserved. Date conversion is unavailable here.':'Date-only deadlines end at 23:59 Manila.'}/>
          <TextField id="deliverable-outcome" name="outcome" label="Outcome" required maxLength={4000} defaultValue={d?.outcome}/>
          <div className="form-field"><label htmlFor="deliverable-criteria">Acceptance criteria (required)</label><textarea id="deliverable-criteria" name="criteria" required maxLength={8000} defaultValue={d?.criteria}/></div>
          <div className="form-field"><label htmlFor="deliverable-body">Working notes</label><textarea id="deliverable-body" name="body" maxLength={20000} defaultValue={d?.body}/></div>
          {!id?<div className="form-field"><label htmlFor="deliverable-visibility">Visibility (required)</label><select id="deliverable-visibility" name="classification" defaultValue="restricted"><option value="restricted">Restricted to participants</option><option value="ordinary">Ordinary core summary</option></select></div>:<p>Visibility: {d?.classification}. Retained for this record.</p>}
          {id?<TextField id="deliverable-reason" name="reason" label="Reason for this change" required maxLength={2000} hint="Required for deadline, ownership and criteria changes."/>:null}
          <button className="button" disabled={busy||uncertain||schedulePending} type="submit">{busy?'Saving…':id?'Save deliverable':canManage&&!propose?'Create deliverable':'Propose commitment'}</button>
        </fieldset>
      </form>:null}
      {id&&context.actions.length?<form data-edit-form data-pending-command={busy||uncertain} onSubmit={transition} className="deliverable-editor"><fieldset disabled={busy||uncertain||schedulePending}>
        <h3>Workflow action</h3><p>Acceptance checks current evidence and mandatory gates on the server. Unresolved gates block acceptance.</p>
        <div className="form-field"><label htmlFor="deliverable-action">Action</label><select id="deliverable-action" name="action" value={action==='none'?context.actions[0]:action} onChange={e=>setAction(e.target.value as DeliverableAction)}>{context.actions.map(a=><option key={a} value={a}>{labels[a]}</option>)}</select></div>
        <TextField id="transition-reason" name="reason" label="Action reason" required maxLength={2000}/>
        <div className="form-field"><label htmlFor="deliverable-evidence">Final evidence or criteria verification notes</label><textarea id="deliverable-evidence" name="evidence" maxLength={4000}/></div>
        {(action==='none'?context.actions[0]:action)==='accept'?<label className="editor-check"><input name="confirmed" type="checkbox" required/>I verified every criterion in revision {context.criteriaRevision} against the final evidence.</label>:null}
        <p className="muted">Final evidence is required to submit. File verification and governed approvals remain separate checks.</p>
        <button className="button" type="submit">{busy?'Applying…':labels[action==='none'?context.actions[0]:action]}</button>
      </fieldset></form>:null}
    </>}
    {id&&timeline?<ScheduleEditor key={id} api={timeline} id={id} disabled={busy||uncertain} onPendingChange={setSchedulePending}/>:null}
  </>
  return id?<Panel title="Manage deliverable">{content}</Panel>:<details className="panel"><summary>Create or propose a deliverable{context?.queue.length?` · ${context.queue.length} awaiting owner reassignment`:''}</summary>{content}</details>
}
