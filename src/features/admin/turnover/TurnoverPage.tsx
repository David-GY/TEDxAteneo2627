import {useCallback,useEffect,useRef,useState} from 'react'
import {Link,useParams,useRouteLoaderData} from 'react-router'
import {PageHeading,Panel} from '../../../components/Page'
import {EmptyState,ErrorState,LoadingState} from '../../../components/FeedbackState'
import type {WorkspaceContext} from '../../auth/gateway'
import {forgetRecordDrafts} from '../../auth/draftScope'
import type {ArchivedCustody,TurnoverApi,TurnoverSetup,TurnoverState,TurnoverWorkspace} from './api'
import {TurnoverEditor,categoryName,type TurnoverEdit} from './TurnoverEditor'
import {archivePath,ArchiveFacts} from './ArchivePage'
import './turnover.css'
const stateName:Record<TurnoverState,string>={preparing:'Review unit and item outcomes',frozen:'Frozen — arrange custody and export',exporting:'Archive operator action required',verified:'Verified — successor review required',rehearsal_verified:'Rehearsal verified — successor review required',complete:'Handover complete',rehearsal_complete:'Rehearsal complete'}
export function TurnoverLinks({api,term}:{api:TurnoverApi;term:string}){
  const [w,setW]=useState<TurnoverWorkspace|null>(null),sequence=useRef(0)
  useEffect(()=>{let live=true;const check=()=>{const n=++sequence.current;setW(null);void api.workspace(term).then(v=>{if(live&&sequence.current===n)setW(v)}).catch(()=>{})};check();window.addEventListener('focus',check);return()=>{live=false;window.removeEventListener('focus',check)}},[api,term])
  return <div className="auth-actions">{w&&(w.case||w.approvals.length)?<Link className="button button--secondary" to={'/handover'+(w.case?'/'+w.case.id:'')+'?term='+term}>Term handover</Link>:null}
    {w?.hasArchive?<Link className="button button--secondary" to={archivePath(term)}>Find archived work</Link>:null}</div>
}
export function TurnoverPage({api}:{api:TurnoverApi}){
  const c=useRouteLoaderData('workspace')as WorkspaceContext,{turnoverCaseId}=useParams()
  if(!('memberId'in c))return <EmptyState title="Handover unavailable" description="Current core workspace access is required."/>
  return <TurnoverBody key={c.memberId+c.termId+turnoverCaseId} api={api} term={c.termId} membership={c.termMembershipId} caseId={turnoverCaseId}/>
}
function TurnoverBody({api,term,membership,caseId}:{api:TurnoverApi;term:string;membership:string;caseId?:string}){
  const [w,setW]=useState<TurnoverWorkspace|null>(null),[setup,setSetup]=useState<TurnoverSetup|null>(null),[custody,setCustody]=useState<ArchivedCustody|null>(null)
  const [checking,setChecking]=useState(true),[failed,setFailed]=useState(false),[edit,setEdit]=useState<TurnoverEdit|null>(null),[notice,setNotice]=useState('')
  const sequence=useRef(0),previous=useRef<{caseId:string|null;canManage:boolean;records:string[];managerRecords:string[]}|null>(null),choice=useRef<TurnoverEdit|null>(null),focus=useRef<HTMLDivElement>(null),completed=useRef(false)
  const load=useCallback(async()=>{
    if(completed.current)return
    const n=++sequence.current;setChecking(true);setFailed(false)
    try{
      const next=await api.workspace(term,caseId)
      const settings=next.canManage||next.approvals.length?await api.setup(term):null
      const q=choice.current,details=q?.kind==='custodyAction'&&next.custody.some(x=>x.id===q.id&&x.recipient===membership&&x.qualified)?await api.custody(term,q.id):null
      if(sequence.current!==n)return
      const old=previous.current,visible=new Set([...next.transfers,...next.custody].map(x=>x.id))
      for(const id of old?.records??[])if(!visible.has(id))forgetRecordDrafts(id)
      if(old?.caseId&&(!next.case||old.canManage&&!next.canManage)){forgetRecordDrafts(old.caseId);old.managerRecords.forEach(forgetRecordDrafts);choice.current=null;setEdit(null)}
      if(q&&'id'in q&&!next.canManage&&!visible.has(q.id)){choice.current=null;setEdit(null);setNotice('Your handover scope changed. Ask the named custodian to review it.')}
      previous.current={caseId:next.case?.id??null,canManage:next.canManage,records:[...visible],managerRecords:[...next.units,...next.work].map(r=>r.id)};setW(next);setSetup(settings);setCustody(details)
    }catch{if(sequence.current===n){setFailed(true);setW(null);setSetup(null);setCustody(null)}}finally{if(sequence.current===n)setChecking(false)}
  },[api,term,caseId,membership])
  useEffect(()=>{const check=()=>{if(document.visibilityState!=='hidden')void load()};check();window.addEventListener('focus',check);document.addEventListener('visibilitychange',check);const timer=setInterval(check,30000);return()=>{sequence.current++;clearInterval(timer);window.removeEventListener('focus',check);document.removeEventListener('visibilitychange',check)}},[load])
  useEffect(()=>{if(edit||notice)focus.current?.focus()},[edit,notice])
  async function open(q:TurnoverEdit){setNotice('');choice.current=q;if(q.kind==='custodyAction'){
    setChecking(true);setCustody(null);try{const d=await api.custody(term,q.id);if(choice.current===q){setCustody(d);setEdit(q)}}catch{setFailed(true);setW(null)}finally{setChecking(false)}
  }else setEdit(q)}
  function close(){choice.current=null;setEdit(null);setCustody(null)}
  function saved(message:string){
    if(choice.current?.kind==='complete'){
      const synthetic=w?.case?.scope==='synthetic';completed.current=true;sequence.current++;close();setW(null);setSetup(null);setCustody(null);setChecking(false)
      setNotice(synthetic?'Rehearsal handover completed. The original term is archived; real operational custody remains unverified.':'Handover completed. The original term is archived and selected outgoing scopes were revoked.');return
    }
    close();setNotice(message);void load()
  }
  const acceptedCurrent=(v:{accepted:boolean;acceptedRun:string|null})=>v.accepted&&v.acceptedRun===w?.runs[0]?.id
  const c=w?.case,done=c?.state==='complete'||c?.state==='rehearsal_complete',verified=c?.state==='verified'||c?.state==='rehearsal_verified'
  return <div className="turnover">
    <PageHeading title="Term handover" description="Named responsibility, verified archives and explicit successor acceptance."/>
    <div className="auth-actions"><Link className="button button--secondary" to={completed.current?'/':'/?term='+term}>Overview</Link>{w?.hasArchive?<Link className="button button--secondary" to={archivePath(term)}>Find archived work</Link>:null}{!completed.current?<button className="button button--secondary" disabled={checking} onClick={()=>void load()}>Refresh current access</button>:null}</div>
    {completed.current?<Panel title="Handover recorded"><p role="status">{notice}</p></Panel>:null}
    {checking?<LoadingState title="Checking current handover scope"/>:null}
    {failed?<ErrorState title="Handover could not be checked" description="Check your connection and verified session. Private records are hidden; safe entries stay in memory for an exact retry."/>:null}
    {!checking&&!failed&&w&&!c&&!w.approvals.length?<EmptyState title="No handover assigned" description="Only authorized custodians and named successors see a term handover. Ask the process contact to review your scope."/>:null}
    {w?<div hidden={failed||checking}>
      {c?<Panel title={c.term}><p><strong>{stateName[c.state]}</strong></p><p>Accountable custodian: {c.custodian}.</p>{c.scope==='synthetic'?<p role="note">Synthetic rehearsal only. This does not prove real account custody, provider recovery or participant acceptance.</p>:null}
        {w.runs[0]?.failure&&!w.runs[0].restored?<p role="alert">Archive operator: the {w.runs[0].failure.phase==='files'?'file checks':w.runs[0].failure.phase==='restore'?'restore rehearsal':'record checks'} need attention. Recheck the approved source and resume the current generation; verification remains blocked.</p>:null}
      </Panel>:null}
      <div ref={focus} tabIndex={-1}>{notice?<p role="status">{notice}</p>:null}
        {edit?<TurnoverEditor key={edit.kind+('id'in edit?edit.id:'')+('action'in edit?edit.action:'')} api={api} term={term} workspace={w} setup={setup} custody={custody} edit={edit} checking={checking} refresh={()=>void load()} saved={saved} close={close}/>:null}</div>
      {!edit&&!c&&w.approvals.length?<button className="button" onClick={()=>void open({kind:'prepare'})}>Start authorized closure</button>:null}
      {w.canManage&&c?<>
        <Panel title="1. Review unit responsibility"><ul className="turnover-list">{w.units.map(u=><li key={u.id}><h3>{u.name}</h3><p>{u.checked?'Review recorded':'Review needed'} · {w.people.find(p=>p.id===u.owner)?.name??'Name a responsible person'}</p>{c.state==='preparing'&&!edit?<button className="button button--secondary" onClick={()=>void open({kind:'unit',id:u.id})}>Record review for {u.name}</button>:null}</li>)}</ul></Panel>
        <Panel title="2. Resolve or carry each item"><ul className="turnover-list">{w.work.map(x=><li key={x.id}><h3>{x.reference?x.reference+' · ':''}{x.title}</h3><p>{categoryName(x.classification)} · {x.resolution==='carry'?'Carry forward':x.resolution==='resolved'?'Resolved':x.resolution==='cancelled'?'Cancelled':'Outcome needed'}{x.recordedVersion!==x.version&&x.resolution?' · Source changed; review again':''}</p><p>Responsible person: {w.people.find(p=>p.id===x.owner)?.name??'Not yet recorded'}{x.successor?' · Successor: '+(w.successors.find(p=>p.id===x.successor)?.name??'Review current successor'):''}</p>{c.state==='preparing'&&!edit?<button className="button button--secondary" onClick={()=>void open({kind:'obligation',id:x.id})}>Record outcome for {x.reference??x.title}</button>:null}</li>)}</ul></Panel>
        <Panel title="3. Plan scopes and verify the archive"><div className="auth-actions">
          {!edit&&c.state==='preparing'?<><button className="button button--secondary" onClick={()=>void open({kind:'transfer'})}>Plan ordinary handover</button><button className="button" onClick={()=>void open({kind:'freeze'})}>Review term freeze</button></>:null}
          {!edit&&['preparing','frozen'].includes(c.state)?<button className="button button--secondary" onClick={()=>void open({kind:'nominate'})}>Name a private-record custodian</button>:null}
          {!edit&&['frozen','exporting','verified','rehearsal_verified'].includes(c.state)?<button className="button" onClick={()=>void open({kind:'archive'})}>{c.state==='exporting'?'Resume archive generation':'Prepare archive generation'}</button>:null}
          {!edit&&c.state==='exporting'?<button className="button button--secondary" onClick={()=>void open({kind:'verify'})}>Check archive verification</button>:null}
          {!edit&&verified?<button className="button" onClick={()=>void open({kind:'complete'})}>Review handover completion</button>:null}
        </div><p>The approved operator owns record/file export and isolated restore checks. Incoming-term activation and fresh role/custody grants are separate authorized administration actions.</p>
          <details><summary>Scoped archive evidence</summary>{w.categories.map((r,i)=><p key={i}>{categoryName(r.category)} · {r.disposition==='hold'?'Held':r.disposition==='carry'?'Carried forward':r.disposition==='dispose'?'Disposal review':'Archived'} · {r.rows} rows · Review {r.reviewOn}</p>)}{w.runs.map(r=><p key={r.id}>{new Date(r.at).toLocaleString('en-PH',{timeZone:'Asia/Manila'})} (Manila) · {r.restored?'Restore evidence recorded':'Operator checks pending'}</p>)}</details>
        </Panel>
      </>:null}
      {c?<Panel title="4. Review named successor duties">
        {!w.transfers.length&&!w.custody.length?<p>The custodian has not named a transfer or private-record custodian yet.</p>:null}
        {w.transfers.map(t=><section key={t.id}><h3>{t.name} · {t.term}</h3><p>{t.reference}</p><p>{acceptedCurrent(t)?'Named records accepted':'Record acceptance pending'}</p><ul className="turnover-list">{t.work.map(x=><li key={x.id}><h3>{x.title}</h3><ArchiveFacts record={x}/><details><summary>Review retained record</summary><p className="record-text">{x.body}</p></details></li>)}</ul>{!edit&&verified&&!acceptedCurrent(t)&&t.successor===membership?<button className="button" onClick={()=>void open({kind:'acceptRecords',id:t.id})}>Review acceptance of named records</button>:null}</section>)}
        {w.custody.map(n=><section key={n.id}><h3>{n.name} · {categoryName(n.category)}</h3><p>{n.reference}</p><p>{acceptedCurrent(n)?'Metadata custody accepted':'Custody acceptance pending'} · {n.qualified?'Current qualification':'Qualification needs review'} · Until {new Date(n.expiresAt).toLocaleDateString('en-PH',{timeZone:'Asia/Manila'})}</p><ul>{n.records.map((r,i)=><li key={r.id}>{r.reference??'Custody record '+(i+1)}</li>)}</ul>{!edit&&verified&&!acceptedCurrent(n)&&n.qualified&&n.recipient===membership?<button className="button" onClick={()=>void open({kind:'acceptCustody',id:n.id})}>Review acceptance of {categoryName(n.category)} custody</button>:null}
          {!edit&&done&&n.recipient===membership&&n.qualified?<div className="auth-actions">{(['hold','correction','release_hold']as const).map(action=><button key={action} className="button button--secondary" onClick={()=>void open({kind:'custodyAction',id:n.id,action})}>{action==='hold'?'Place a preservation hold':action==='correction'?'Append a correction reference':'Review hold release'}</button>)}</div>:null}
        </section>)}
      </Panel>:null}
    </div>:null}
  </div>
}
