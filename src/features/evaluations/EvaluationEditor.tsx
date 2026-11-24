import {useId,useRef,type FormEvent} from 'react'
import {Panel} from '../../components/Page'
import {useFinDecision} from '../finance/DecisionMemory'
import {forgetRecordDrafts} from '../auth/draftScope'
import type {EvaluationCommand,EvaluationRecord,EvaluationsApi,EvaluationSetup} from './api'

export type EvaluationEdit={kind:'submit'|'note'|'prepareRelease';record:EvaluationRecord}|
  {kind:'publishRelease';record:EvaluationRecord;draft:EvaluationRecord['releaseDrafts'][number]}|
  {kind:'grantExport';caseRecord:EvaluationSetup['rounds'][number]['cases'][number];people:EvaluationSetup['people']}
const title={submit:'Your feedback',note:'Add an attributed reviewer note',prepareRelease:'Prepare a subject summary',
  publishRelease:'Review summary release',grantExport:'Approve a scoped export'}

export function EvaluationEditor({api,term,edit,checking,refresh,saved,close}:{api:EvaluationsApi;term:string;edit:EvaluationEdit;
  checking:boolean;refresh:()=>void;saved:(notice:string)=>void;close:()=>void}){
  const r='record'in edit?edit.record:null,own=r?.submissions.find(s=>s.own)
  const id=useId(),running=useRef(false),caseId=r?.caseId??('caseRecord'in edit?edit.caseRecord.id:'')
  const version=edit.kind==='submit'?own?.revision??0:edit.kind==='publishRelease'?edit.draft.version:r?.version??('caseRecord'in edit?edit.caseRecord.version:0)
  const initial={...Object.fromEntries(r?.template.map(p=>['answer_'+p.key,own?.answers?.[p.key]??''])??[]),
    __base:String(version),__dirty:'',body:'',member:'',purpose:'',expires:''}
  const m=useFinDecision(api,'prism:'+term+':'+caseId+':'+edit.kind,initial)
  const fields=m.fields,stale=Number(fields.__base)!==version
  const changed=(key:string,value:string)=>m.change({...fields,[key]:value,__dirty:'1'})
  async function send(command?:EvaluationCommand){
    if(running.current)return
    running.current=true
    try{const result=await m.run(command);if(result)saved(edit.kind==='submit'?'Feedback revision saved.':
      edit.kind==='note'?'Reviewer note saved.':edit.kind==='prepareRelease'?'Summary prepared. Independent release is pending.':
      edit.kind==='publishRelease'?'Summary released to the named subject.':'Export approval recorded.');else refresh()}
    finally{running.current=false}
  }
  function submit(e:FormEvent){
    e.preventDefault();if(m.locked||checking||stale)return
    const base=Number(fields.__base)
    if(edit.kind==='submit'&&r)void send({term,kind:'submit',caseId,revision:base,withdraw:false,
      answers:Object.fromEntries(r.template.map(p=>[p.key,fields['answer_'+p.key]??'']))})
    else if(edit.kind==='note')void send({term,kind:'note',caseId,version:base,body:fields.body})
    else if(edit.kind==='prepareRelease'&&r)void send({term,kind:'prepareRelease',caseId,version:base,subject:r.subjectId,summary:fields.body})
    else if(edit.kind==='publishRelease'&&r)void send({term,kind:'publishRelease',draft:edit.draft.id,version:base,subject:r.subjectId})
    else if(edit.kind==='grantExport'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(fields.expires)){
      const expiry=new Date(fields.expires+':00+08:00')
      if(Number.isFinite(expiry.getTime()))void send({term,kind:'grantExport',caseId,version:base,member:fields.member,
        expiresAt:expiry.toISOString(),purposeReference:fields.purpose})
    }
  }
  return <Panel title={title[edit.kind]}>
    {r?<p><strong>{r.subject}</strong> · {r.round}</p>:null}
    {m.error?<p role="alert">{m.error}</p>:null}
    {m.pending?<p role="status">The save result is uncertain. Check the same attempt before changing it.</p>:null}
    {m.pending?<button className="button" disabled={checking||m.busy} onClick={()=>void send()}>Check whether saved / try again</button>:null}
    {stale&&!m.pending?<div role="alert"><p>Saved evidence changed. Your entries are kept. Review the latest record before sending.</p>
      <button className="button button--secondary" onClick={()=>m.change({...fields,__base:String(version)})}>Keep entries and review latest</button></div>:null}
    <form onSubmit={submit} data-unsaved-changes={fields.__dirty==='1'} data-pending-command={m.locked}>
      <fieldset disabled={m.locked||stale||checking}>
        {edit.kind==='submit'&&r?<><p>This saves a new revision of your own evidence. Earlier submissions stay in history. Authorized reviewers see your name.</p>
          {r.template.map(p=><div className="form-field" key={p.key}><label htmlFor={id+p.key}>{p.label}{p.required?'':' (optional)'}</label>
            <textarea id={id+p.key} value={fields['answer_'+p.key]??''} required={p.required} maxLength={p.maxLength}
              onChange={e=>changed('answer_'+p.key,e.target.value)}/></div>)}</>:null}
        {edit.kind==='note'||edit.kind==='prepareRelease'?<div className="form-field">
          <p>{edit.kind==='note'?'Your name stays on this internal note. Subjects do not receive it.':
            'Write an appropriate subject-facing summary. Remove third-party identities and unnecessary private detail. A different assigned releaser must review it.'}</p>
          <label htmlFor={id+'body'}>{edit.kind==='note'?'Reviewer note':'Subject-facing summary'}</label>
          <textarea id={id+'body'} required maxLength={edit.kind==='note'?4000:6000} value={fields.body} onChange={e=>changed('body',e.target.value)}/>
        </div>:null}
        {edit.kind==='publishRelease'?<><p>Release this exact summary to <strong>{edit.record.subject}</strong>. Raw feedback and internal notes stay separate.</p>
          <p className="record-text">{edit.draft.summary}</p><p>Confirm that this is the correct subject and current evidence, with no inappropriate third-party disclosure.</p></>:null}
        {edit.kind==='grantExport'?<>
          <p>The named recipient can download only their currently authorized projection for this exact case version. Copies need separate custody and retention.</p>
          <div className="form-field"><label htmlFor={id+'member'}>Current recipient</label><select id={id+'member'} value={fields.member} required onChange={e=>changed('member',e.target.value)}>
            <option value="">Choose a named participant</option>{edit.people.filter(p=>edit.caseRecord.assignments.some(a=>a.memberId===p.id&&a.active))
              .map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></div>
          <div className="form-field"><label htmlFor={id+'purpose'}>Approved disclosure purpose</label><input id={id+'purpose'} required minLength={3} maxLength={500} value={fields.purpose} onChange={e=>changed('purpose',e.target.value)}/></div>
          <div className="form-field"><label htmlFor={id+'expires'}>Approval ends (Manila)</label><input id={id+'expires'} type="datetime-local" required value={fields.expires} onChange={e=>changed('expires',e.target.value)}/></div>
        </>:null}
        <button className="button">{edit.kind==='submit'?'Save feedback revision':edit.kind==='note'?'Save reviewer note':
          edit.kind==='prepareRelease'?'Prepare summary for independent review':edit.kind==='publishRelease'?'Release this summary':'Approve this export'}</button>
      </fieldset>
    </form>
    <button className="button button--secondary" disabled={m.locked} onClick={()=>{
      if(fields.__dirty==='1'&&!window.confirm('Discard these unsaved entries?'))return
      forgetRecordDrafts(caseId);close()
    }}>Close editor</button>
  </Panel>
}

export function EvaluationAction({api,id,command,label,notice,checking,saved,refresh,confirm}:{api:EvaluationsApi;id:string;
  command:EvaluationCommand;label:string;notice:string;checking:boolean;saved:(notice:string)=>void;refresh:()=>void;confirm?:string}){
  const m=useFinDecision(api,'prism:'+command.term+':'+id+':'+command.kind,{})
  const running=useRef(false)
  async function act(){
    if(running.current||!m.pending&&confirm&&!window.confirm(confirm))return
    running.current=true
    try{const result=await m.run(command);if(result)saved(notice);else refresh()}
    finally{running.current=false}
  }
  return <>{m.error?<p role="alert">{m.error}</p>:null}<button className="button button--secondary" disabled={checking||m.busy}
    onClick={()=>void act()}>{m.pending?'Check whether saved / try again':label}</button></>
}
