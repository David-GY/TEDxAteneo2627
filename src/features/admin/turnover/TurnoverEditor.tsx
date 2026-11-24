import {useId,useRef,type FormEvent} from 'react'
import {Panel} from '../../../components/Page'
import {useFinDecision} from '../../finance/DecisionMemory'
import type {ArchivedCustody,TurnoverApi,TurnoverCommand,TurnoverSetup,TurnoverWorkspace} from './api'

export type TurnoverEdit={kind:'unit'|'obligation';id:string}|{kind:'transfer'|'nominate'|'prepare'|'freeze'|'archive'|'verify'|'complete'}|
  {kind:'acceptRecords'|'acceptCustody';id:string}|{kind:'custodyAction';id:string;action:'hold'|'release_hold'|'correction'}
export const categoryName=(v:string)=>({operational:'Ordinary work',restricted:'Restricted records',finance:'Finance',prism:'PRISM confidential records',security:'Security records',privacy:'Privacy records',profile:'Private profiles',guest:'Guest records',learning:'Learning records',backup:'Recovery records'}[v]??'Protected records')
const labels:Record<TurnoverEdit['kind'],string>={unit:'Record unit review',obligation:'Record item outcome',transfer:'Plan ordinary handover',nominate:'Name a private-record custodian',prepare:'Start authorized closure',freeze:'Review term freeze',archive:'Prepare archive generation',verify:'Check archive verification',complete:'Review handover completion',acceptRecords:'Accept named records',acceptCustody:'Accept metadata custody',custodyAction:'Record archived custody action'}
export function TurnoverEditor({api,term,workspace:w,setup,custody,edit,checking,refresh,saved,close}:{api:TurnoverApi;term:string;workspace:TurnoverWorkspace;setup:TurnoverSetup|null;custody:ArchivedCustody|null;edit:TurnoverEdit;checking:boolean;refresh:()=>void;saved:(message:string)=>void;close:()=>void}){
  const input=useId(),running=useRef(false),target='id'in edit?edit.id:w.case?.id??term
  const unit=w.units.find(u=>'id'in edit&&u.id===edit.id),work=w.work.find(x=>'id'in edit&&x.id===edit.id)
  const base=edit.kind==='custodyAction'?custody?.version??0:w.case?.version??0
  const m=useFinDecision(api,'turnover:'+term+':'+target+':'+edit.kind+('action'in edit?edit.action:''),{
    __base:String(base),__dirty:'',reference:'',owner:work?.owner??unit?.owner??'',successor:work?.successor??'',
    outcome:work?.state==='completed'?'resolved':work?.state==='cancelled'?'cancelled':'carry',approval:w.approvals[0]?.id??'',authority:'',reviewAt:'',hold:'',confirmed:'',
    ...Object.fromEntries([...w.work,...(setup?.privateRoots??[])].map(r=>['work_'+r.id,''])),
    ...Object.fromEntries(w.roles.map(r=>['role_'+r.id,''])),...Object.fromEntries(w.grants.map(g=>['grant_'+g.id,''])),
  })
  const f=m.fields,stale=Number(f.__base)!==base,run=w.runs.find(r=>r.restored)
  const change=(key:string,value:string)=>m.change({...f,...(key==='authority'?Object.fromEntries(Object.keys(f).filter(k=>k.startsWith('work_')).map(k=>[k,''])):{}),[key]:value,__dirty:'1'})
  const selected=(prefix:string)=>Object.entries(f).filter(([k,v])=>k.startsWith(prefix)&&v==='1').map(([k])=>k.slice(prefix.length))
  const authority=setup?.authorities.find(a=>a.id===f.authority)
  async function send(command?:TurnoverCommand){
    if(running.current)return;running.current=true
    try{const result=await m.run(command);if(result)saved(edit.kind==='acceptRecords'?'Named records accepted.':edit.kind==='acceptCustody'?'Metadata custody accepted.':'Handover action recorded.');else refresh()}
    finally{running.current=false}
  }
  function submit(e:FormEvent){
    e.preventDefault();if(checking||m.locked||stale)return
    const c=w.case,version=Number(f.__base),reference=f.reference
    if(edit.kind==='prepare')void send({kind:'prepare',term,approval:f.approval})
    else if(edit.kind==='unit'&&c)void send({kind:'update',caseId:c.id,version,action:'unit',values:{unit:edit.id,owner:f.owner,reference}})
    else if(edit.kind==='obligation'&&c&&work)void send({kind:'update',caseId:c.id,version,action:'obligation',values:{work:work.id,workVersion:work.version,owner:f.owner,resolution:f.outcome,successor:f.outcome==='carry'?f.successor:null,reference}})
    else if(edit.kind==='transfer'&&c)void send({kind:'update',caseId:c.id,version,action:'transfer',values:{successor:f.successor,work:selected('work_'),roles:selected('role_'),grants:selected('grant_'),reference}})
    else if(edit.kind==='nominate'&&c&&authority)void send({kind:'nominate',caseId:c.id,version,recipient:authority.recipient,category:authority.category,work:selected('work_'),authority:authority.id,expiresAt:authority.expiresAt,reference})
    else if((edit.kind==='freeze'||edit.kind==='archive')&&c)void send({kind:edit.kind,caseId:c.id,version})
    else if((edit.kind==='verify'||edit.kind==='complete')&&c&&w.runs[0])void send({kind:edit.kind,caseId:c.id,version,run:w.runs[0].id,reference})
    else if((edit.kind==='acceptRecords'||edit.kind==='acceptCustody')&&run)void send({kind:edit.kind,term,id:edit.id,run:run.id,reference})
    else if(edit.kind==='custodyAction'&&custody){
      const hold=custody.holds.find(h=>h.id===f.hold)
      const values:Record<string,string|number>=edit.action==='release_hold'?{hold:f.hold,holdVersion:hold?.version??0}:edit.action==='hold'?{work:f.successor,reviewAt:new Date(f.reviewAt+':00+08:00').toISOString()}:{work:f.successor}
      void send({kind:'custodyAction',term,id:edit.id,version,action:edit.action,values,reference})
    }
  }
  const choice=(key:string,label:string,options:{id:string;name:string}[])=> <div className="form-field"><label htmlFor={input+key}>{label}</label><select id={input+key} required value={f[key]} onChange={e=>change(key,e.target.value)}><option value="">Choose {label.toLowerCase()}</option>{options.map(o=><option key={o.id} value={o.id}>{o.name}</option>)}</select></div>
  const checks=(prefix:string,items:{id:string;name:string}[])=>items.map(r=><label className="turnover-check" key={r.id}><input type="checkbox" checked={f[prefix+r.id]==='1'} onChange={e=>change(prefix+r.id,e.target.checked?'1':'')}/><span>{r.name}</span></label>)
  const requiresNote=!['prepare','freeze','archive','verify'].includes(edit.kind)
  return <Panel title={labels[edit.kind]}>
    {m.error?<p role="alert">{m.error}</p>:null}
    {m.pending?<><p role="status">The result is uncertain. Check the same saved attempt before changing its details.</p><button className="button" disabled={checking||m.busy} onClick={()=>void send()}>Check whether saved / try again</button></>:null}
    {stale&&!m.pending?<div role="alert"><p>The handover changed. Your entries are kept. Review the latest checklist before sending.</p><button className="button button--secondary" onClick={()=>m.change({...f,__base:String(base)})}>Keep entries and review latest</button></div>:null}
    <form onSubmit={submit} data-unsaved-changes={f.__dirty==='1'} data-pending-command={m.locked}><fieldset disabled={checking||m.locked||stale}>
      {edit.kind==='prepare'?choice('approval','Recorded authorization',w.approvals.map(a=>({id:a.id,name:a.reference+' · '+(a.scope==='synthetic'?'Rehearsal':'Operational')}))):null}
      {edit.kind==='unit'||edit.kind==='obligation'?<><p>{unit?.name??work?.reference??work?.title}</p>{choice('owner','Responsible person',w.people)}</>:null}
      {edit.kind==='obligation'?<>
        {choice('outcome','Outcome',work?.state==='completed'?[{id:'resolved',name:'Resolved — already completed'}]:work?.state==='cancelled'?[{id:'cancelled',name:'Cancelled — recorded in the source'}]:[{id:'carry',name:'Carry forward — needs successor acceptance'}])}
        {f.outcome==='carry'?choice('successor','Successor',w.successors.map(p=>({id:p.id,name:p.name+' · '+p.term}))):null}
      </>:null}
      {edit.kind==='transfer'?<>
        <p>Only these ordinary records will become readable in the successor’s archive. Selected outgoing access will be revoked after verified acceptance. Existing private duties need a separate qualified custodian.</p>
        {choice('successor','Successor',w.successors.map(p=>({id:p.id,name:p.name+' · '+p.term})))}
        <fieldset><legend>Ordinary records</legend>{checks('work_',w.work.filter(x=>x.transferable).map(x=>({id:x.id,name:(x.reference?x.reference+' · ':'')+x.title})))}</fieldset>
        <details><summary>Outgoing access to revoke</summary><fieldset><legend>Role scopes</legend>{checks('role_',w.roles)}</fieldset><fieldset><legend>Record grants</legend>{checks('grant_',w.grants)}</fieldset></details>
      </>:null}
      {edit.kind==='nominate'?<>
        <p>Metadata custody permits scoped holds and correction references. It does not grant raw financial, evaluation or file access. The recipient needs independently granted current authority in the incoming term.</p>
        {choice('authority','Qualified incoming custodian',setup?.authorities.map(a=>({id:a.id,name:a.name+' · '+categoryName(a.category)}))??[])}
        {!setup?.authorities.length?<p>Activate the separately approved incoming term and record its independent custody/role grants, then refresh this checklist.</p>:null}
        {authority?<fieldset><legend>Records for {categoryName(authority.category)}</legend>{checks('work_',authority.category==='prism'?(setup?.privateRoots??[]).map(r=>({id:r.id,name:r.reference})):w.work.filter(x=>x.classification===authority.category).map(x=>({id:x.id,name:(x.reference?x.reference+' · ':'')+x.title})))}</fieldset>:null}
      </>:null}
      {edit.kind==='freeze'?<p>Freeze blocks ordinary edits to this term. Every unit and item must have a current recorded outcome. Controlled holds and correction references remain separate.</p>:null}
      {edit.kind==='archive'?<p>This prepares or resumes the current generation. The approved archive operator must export the records and files, verify their encrypted copies and perform an actual isolated restore before verification can pass.</p>:null}
      {edit.kind==='verify'?<p>Check the operator’s current file and restore evidence. Missing or changed records cannot pass. Rehearsal evidence remains labelled as rehearsal.</p>:null}
      {edit.kind==='complete'?<p>Complete only after every named successor and private-record custodian has accepted the current verified archive. This archives the source term and revokes only the selected outgoing scopes.</p>:null}
      {edit.kind==='acceptRecords'?<p>I reviewed the named ordinary records and understand the carried responsibilities. My acceptance applies to this verified archive only.</p>:null}
      {edit.kind==='acceptCustody'?<p>I reviewed the named metadata duties, expiry and hold/correction process. Raw private contents are not part of this acceptance.</p>:null}
      {edit.kind==='custodyAction'&&custody?<>
        {edit.action==='release_hold'&&!custody.holds.length?<p>No active holds are listed in this custody scope. Close the review or refresh current access before choosing a hold.</p>:null}
        {edit.action==='release_hold'?choice('hold','Hold to release',custody.holds.map(h=>({id:h.id,name:(w.custody.find(n=>n.id===edit.id)?.records.find(r=>r.id===h.objectId)?.reference??'Custody record')+' · Review '+h.reviewAt.slice(0,10)}))):choice('successor','Custody record',(w.custody.find(n=>n.id===edit.id)?.records??[]).map((r,i)=>({id:r.id,name:r.reference??'Custody record '+(i+1)})))}
        {edit.action==='hold'?<div className="form-field"><label htmlFor={input+'date'}>Review date and time (Manila)</label><input id={input+'date'} type="datetime-local" required value={f.reviewAt} onChange={e=>change('reviewAt',e.target.value)}/></div>:null}
        <p>The original content stays unchanged. Record an approved reference for this {edit.action==='release_hold'?'hold release':edit.action==='hold'?'preservation hold':'correction'}.</p>
      </>:null}
      {requiresNote?<div className="form-field"><label htmlFor={input+'note'}>Review note or approved reference</label><textarea id={input+'note'} minLength={3} maxLength={500} required value={f.reference} onChange={e=>change('reference',e.target.value)}/></div>:null}
      {['freeze','complete','acceptRecords','acceptCustody'].includes(edit.kind)?<label className="turnover-check"><input type="checkbox" required checked={f.confirmed==='1'} onChange={e=>change('confirmed',e.target.checked?'1':'')}/><span>I reviewed these responsibilities and consequences.</span></label>:null}
      <div className="auth-actions"><button className="button" type="submit" disabled={edit.kind==='nominate'&&(!authority||!selected('work_').length)||edit.kind==='transfer'&&!selected('work_').length||edit.kind==='custodyAction'&&edit.action==='release_hold'&&!custody?.holds.length}>{labels[edit.kind]}</button><button className="button button--secondary" type="button" onClick={close}>Close review</button></div>
    </fieldset></form>
  </Panel>
}
