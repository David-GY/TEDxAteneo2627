import {useCallback,useEffect,useRef,useState} from 'react'
import {Link,useParams,useRouteLoaderData} from 'react-router'
import {PageHeading,Panel} from '../../components/Page'
import {EmptyState,ErrorState,LoadingState} from '../../components/FeedbackState'
import {forgetRecordDrafts} from '../auth/draftScope'
import type {WorkspaceContext} from '../auth/gateway'
import type {EvaluationCase,EvaluationOwnExport,EvaluationRecord,EvaluationReport,EvaluationSetup,EvaluationSummary,EvaluationWorkspace,EvaluationsApi} from './api'
import {EvaluationAction,EvaluationEditor,type EvaluationEdit} from './EvaluationEditor'
import './evaluations.css'

const date=(v:string)=>new Intl.DateTimeFormat('en-PH',{timeZone:'Asia/Manila',dateStyle:'medium',timeStyle:'short'}).format(new Date(v))+' (Manila)'
const path=(term:string,id?:string,view='feedback')=>'/prism'+(id?'/'+id+'/'+view:'')+'?term='+term

export function EvaluationsLink({api,term}:{api:EvaluationsApi;term:string}){
  const [w,setW]=useState<EvaluationWorkspace|null>(null)
  useEffect(()=>{let live=true;void api.workspace(term).then(v=>{if(live)setW(v)}).catch(()=>{});return()=>{live=false}},[api,term])
  if(!w?.enabled||!w.cases.length)return null
  const own=w.cases.filter(c=>c.asAuthor),reviews=w.cases.filter(c=>c.asReviewer),released=w.cases.filter(c=>c.asSubject&&c.subjectState==='released')
  const direct=new Set([...(own.length===1?own:[]),...(reviews.length===1?reviews:[]),...(released.length===1?released:[])].map(c=>c.id))
  return <div className="auth-actions">
    {own.length===1?<Link className="button button--secondary" to={path(term,own[0].id)}>Open assigned evaluation</Link>:null}
    {released.length===1?<Link className="button button--secondary" to={path(term,released[0].id,'summary')}>Read my released summary</Link>:null}
    {reviews.length===1?<Link className="button button--secondary" to={path(term,reviews[0].id)}>Open assigned PRISM review</Link>:null}
    {w.cases.some(c=>!direct.has(c.id)||c.asCustodian)?
      <Link className="button button--secondary" to={path(term)}>PRISM feedback</Link>:null}
  </div>
}

export function EvaluationsPage({api}:{api:EvaluationsApi}){
  const c=useRouteLoaderData('workspace')as WorkspaceContext,{evaluationId,view}=useParams()
  if(!('memberId'in c))return <EmptyState title="PRISM unavailable" description="Current core workspace access is required."/>
  return <EvaluationBody key={c.termId+c.memberId+evaluationId+view} api={api} term={c.termId} caseId={evaluationId} view={view}/>
}

function EvaluationBody({api,term,caseId,view}:{api:EvaluationsApi;term:string;caseId?:string;view?:string}){
  const [w,setW]=useState<EvaluationWorkspace|null>(null),[r,setR]=useState<EvaluationRecord|null>(null)
  const [summary,setSummary]=useState<EvaluationSummary|null>(null),[grants,setGrants]=useState<EvaluationOwnExport[]>([])
  const [help,setHelp]=useState<{complaintsUrl:string}|null>(null)
  const [checking,setChecking]=useState(true),[failed,setFailed]=useState(false),[notice,setNotice]=useState('')
  const [mode,setMode]=useState<EvaluationEdit['kind']|null>(null),[draftId,setDraftId]=useState<string|null>(null)
  const [page,setPage]=useState(1),sequence=useRef(0),previous=useRef<EvaluationRecord|null>(null),focus=useRef<HTMLDivElement>(null)
  const priorCases=useRef<string[]>([])
  const load=useCallback(async()=>{
    const current=++sequence.current;setChecking(true);setFailed(false)
    try{
      const next=await api.workspace(term,page)
      const record=next.enabled&&caseId&&view==='feedback'?await api.record(term,caseId):null
      const result=next.enabled&&caseId&&view==='summary'?await api.summary(term,caseId):null
      const exports=record?await api.exports(term,record.caseId):[]
      const guidance=next.enabled?await api.help(term):null
      if(sequence.current!==current)return
      const visible=new Set(next.enabled?next.cases.map(c=>c.id):[])
      for(const old of priorCases.current)if(!visible.has(old))forgetRecordDrafts(old)
      priorCases.current=[...visible]
      if(caseId&&(!record&&view==='feedback'||previous.current&&record&&previous.current.reviewer!==record.reviewer||!next.enabled)){
        forgetRecordDrafts(caseId);setMode(null);setDraftId(null)
      }
      if(record&&!record.reviewer&&!previous.current)setMode('submit')
      previous.current=record;setW(next);setR(record);setSummary(result);setGrants(exports);setHelp(guidance)
    }catch{if(sequence.current===current)setFailed(true)}
    finally{if(sequence.current===current)setChecking(false)}
  },[api,term,caseId,view,page])
  useEffect(()=>{
    const check=()=>{if(document.visibilityState!=='hidden')void load()};check()
    window.addEventListener('focus',check);document.addEventListener('visibilitychange',check)
    const timer=setInterval(check,30000)
    return()=>{sequence.current++;clearInterval(timer);window.removeEventListener('focus',check);document.removeEventListener('visibilitychange',check)}
  },[load])
  useEffect(()=>{if(mode||notice)focus.current?.focus()},[mode,notice])
  function saved(message:string){setMode(null);setDraftId(null);setNotice(message);void load()}
  const actions={api,term,checking,saved,refresh:()=>void load()}
  const draft=r?.releaseDrafts.find(d=>d.id===draftId)
  const edit:EvaluationEdit|null=r&&mode&&mode!=='grantExport'?(mode==='publishRelease'?draft?{kind:mode,record:r,draft}:null:{kind:mode,record:r}):null
  const item=w?.cases.find(c=>c.id===caseId)
  const own=r?.submissions.find(s=>s.own)
  return <div className="evaluations">
    <PageHeading title={view==='summary'?'My released summary':view==='feedback'?'Assigned evaluation':'PRISM feedback'}
      description="Confidential developmental feedback, separate from ordinary work and formal complaint handling."/>
    <div className="auth-actions"><Link className="button button--secondary" to="/">Overview</Link>
      {caseId?<Link className="button button--secondary" to={path(term)}>PRISM desk</Link>:null}
      <button className="button button--secondary" disabled={checking} onClick={()=>void load()}>Refresh current access</button></div>
    {checking&&!w?<LoadingState title="Checking current PRISM scope"/>:null}
    {failed?<ErrorState title="PRISM could not be checked" description="Check your connection and verified session. Safe entries are kept in memory; current access is rechecked before saving."
      action={<button className="button" onClick={()=>void load()}>Check access again</button>}/>:null}
    {w?<div hidden={failed} inert={checking}>
      {!w.enabled?<EmptyState title="PRISM is inactive" description="An accountable custodian, recorded basis, approved published retention, independent privacy approval and actual participant UAT must be recorded before activation."
        action={<Link className="button button--secondary" to="/privacy">Privacy and request help</Link>}/>:<>
        <div ref={focus} tabIndex={-1}>{notice?<p role="status">{notice}</p>:null}</div>
        {caseId?view==='summary'?summary?<Panel title={summary.round}>
          <p>{summary.purpose}</p><p><strong>{summary.state==='released'?'Released subject summary':summary.state==='awaiting_updated_summary'?'Awaiting an updated reviewed summary':'Awaiting independent release'}</strong></p>
          {summary.summary?<p className="record-text">{summary.summary}</p>:<p>There is no current summary to read. Raw feedback is not part of your subject view.</p>}
          {summary.releasedAt?<p>Released {date(summary.releasedAt)}</p>:null}
        </Panel>:<Unavailable/>:view==='feedback'&&r?<>
          <Panel title={r.round}><p><strong>{r.subject}</strong> · {r.purpose}</p>
            <p>{r.reviewer?'Assigned PRISM review · raw confidential material':'Only you and current assigned PRISM reviewers can read your feedback in the workspace.'}</p>
            <p>Submit by {date(r.closesAt)}. Amendments close {date(r.appealUntil)}.</p>
            <details className="work-section"><summary>Retention and accountable custody</summary>
              <p>Retention review: {r.retention.days} days after the appeal deadline, subject to holds. Accountable owner: {r.retention.owner}. Basis: {r.retention.basis}.</p>
              <p>{w.anonymity}</p></details>
          </Panel>
          {edit?<EvaluationEditor key={edit.kind+draftId} edit={edit} {...actions} close={()=>setMode(null)}/>:null}
          {!r.reviewer?<Panel title={own?'Your submitted feedback':'Write your feedback'}>
            {own?<p>Revision {own.revision} · {own.state==='submitted'?'Submitted for authorized review':'Withdrawn from current review'}</p>:<p>No feedback has been submitted by you.</p>}
            {!edit?<div className="auth-actions"><button className="button" onClick={()=>setMode('submit')}>{own?'Append a feedback revision':'Write feedback'}</button>
              {own?.state==='submitted'?<EvaluationAction {...actions} id={r.caseId} command={{term,kind:'submit',caseId:r.caseId,revision:own.revision,answers:null,withdraw:true}}
                label="Withdraw current feedback" notice="Feedback withdrawn from current review. History is retained under policy."
                confirm="Withdraw your current feedback from review? The immutable submission history remains under retention and legal holds."/>:null}</div>:null}
            {own?<details className="work-section"><summary>Your immutable submission history</summary>{own.history?.map(h=><article key={h.revision}>
              <h3>Revision {h.revision} · {h.state==='submitted'?'Submitted':'Withdrawn'}</h3><p>{date(h.at)}</p>
              {r.template.map(p=>h.answers?.[p.key]?<p className="record-text" key={p.key}><strong>{p.label}</strong><br/>{h.answers[p.key]}</p>:null)}
            </article>)}</details>:null}
          </Panel>:<>
            <Panel title="Assigned reviewer material">
              <p>If you have a conflict, stop reviewing and ask the privacy custodian to reassign this case.</p>
              {!edit?<div className="auth-actions"><button className="button button--secondary" onClick={()=>setMode('note')}>Add reviewer note</button>
                {r.canPrepare?<button className="button" onClick={()=>setMode('prepareRelease')}>Prepare subject summary</button>:null}</div>:null}
              {!r.submissions.length?<p>No currently eligible submitted feedback is available.</p>:null}
              {r.submissions.map(s=><article key={s.id}><h3>{s.author} · revision {s.revision}</h3>
                {r.template.map(p=>s.answers?.[p.key]?<p className="record-text" key={p.key}><strong>{p.label}</strong><br/>{s.answers[p.key]}</p>:null)}</article>)}
            </Panel>
            <details className="work-section"><summary>Attributed reviewer notes</summary>{r.notes.length?r.notes.map(n=><article key={n.id}>
              <h3>{n.author}</h3><p>{date(n.at)}</p><p className="record-text">{n.body}</p></article>):<p>No internal notes.</p>}</details>
            <Panel title="Separate summary review and release"><p>Release starts {date(r.releaseAfter)}. A different current assigned releaser must review the exact subject and summary.</p>
              {!r.releaseDrafts.length?<p>No summary has been prepared for release.</p>:null}
              {r.releaseDrafts.map(d=><article key={d.id}><h3>{d.published?'Published subject summary':d.current?'Current summary draft':'Superseded summary draft'}</h3><p className="record-text">{d.summary}</p>
                <p>{d.own?'Prepared by you · independent release required':'Prepared by another assigned reviewer'}</p>
                {r.canRelease&&d.current&&!d.published&&!d.own&&!edit?<button className="button" onClick={()=>{setDraftId(d.id);setMode('publishRelease')}}>Review release to {r.subject}</button>:null}
              </article>)}</Panel>
          </>}
          <ExportRecord api={api} term={term} caseId={r.caseId} grants={grants} checking={checking}/>
        </>:<Unavailable/>:<>
          {!w.cases.length?<EmptyState title="No current PRISM assignments" description="Feedback is optional. Current assignments and released results appear here. Your ordinary work stays in Overview."/>:null}
          {w.cases.some(c=>c.asAuthor)?<DeskList title="Feedback I author" cases={w.cases.filter(c=>c.asAuthor)} term={term}/>:null}
          {w.cases.some(c=>c.asReviewer)?<DeskList title="Assigned PRISM review queue" cases={w.cases.filter(c=>c.asReviewer)} term={term}/>:null}
          {w.cases.some(c=>c.asSubject)?<DeskList title="My released results" cases={w.cases.filter(c=>c.asSubject)} term={term} subject/>:null}
          {w.hasMore||page>1?<div className="auth-actions"><button className="button button--secondary" disabled={page===1} onClick={()=>setPage(p=>p-1)}>Previous cases</button>
            <button className="button button--secondary" disabled={!w.hasMore} onClick={()=>setPage(p=>p+1)}>Next cases</button></div>:null}
          {w.cases.some(c=>c.asCustodian)?<Custody {...actions}/>:null}
        </>}
        <details className="work-section"><summary>Privacy, rights and formal complaints</summary>
          <p>{w.anonymity}</p><p>Feedback is optional. Submission is evidence, not an approval or disciplinary finding. Access or correction requests are reviewed separately; they do not automatically disclose other people's narratives.</p>
          {item?<Retention item={item}/>:null}
          <Link className="button button--secondary" to={'/privacy?term='+term}>Privacy rights and requests</Link>
          <p>Use the approved school process for allegations or formal complaints. Do not put them in this developmental feedback form.</p>
          {help?<a className="button button--secondary" href={help.complaintsUrl} target="_blank" rel="noreferrer">Approved school complaint process</a>:<p>The approved school process is unavailable. Ask the privacy custodian through Privacy rights and requests.</p>}
        </details>
      </>}
    </div>:null}
  </div>
}
function Unavailable(){return <EmptyState title="Evaluation unavailable" description="Current assignment or subject access could not be confirmed. Return to the desk; knowing a link does not grant access."/>}
function Retention({item}:{item:EvaluationCase}){return <p>Retention review: {item.retention.days} days after the round's appeal deadline, subject to legal holds and custody policy. Accountable owner: {item.retention.owner}. Basis: {item.retention.basis}.</p>}
function DeskList({title,cases,term,subject=false}:{title:string;cases:EvaluationCase[];term:string;subject?:boolean}){
  return <Panel title={title}>{!cases.length?<p>No current cases in this view.</p>:<ul className="evaluation-list">{cases.map(c=><li key={c.id}>
    <h3>{c.round}{!subject&&c.subject?' · '+c.subject:''}</h3><p>{c.purpose}</p>
    <p>{subject?c.subjectState==='released'?'Released summary available':'Awaiting independent summary release':c.asAuthor?c.authorState==='submitted'?'Your feedback is submitted':c.authorState==='withdrawn'?'Your feedback is withdrawn':'Your feedback has not been submitted':'Current assigned review'}</p>
    <Link className="button" to={path(term,c.id,subject?'summary':'feedback')}>{subject?'Read subject summary':c.asAuthor?'Open assigned evaluation':'Open assigned review'}</Link>
  </li>)}</ul>}</Panel>
}
function ExportRecord({api,term,caseId,grants,checking}:{api:EvaluationsApi;term:string;caseId:string;grants:EvaluationOwnExport[];checking:boolean}){
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),live=useRef(true)
  useEffect(()=>{live.current=true;return()=>{live.current=false}},[])
  async function download(grant:string){
    setBusy(true);setError('')
    try{const record=await api.exportRecord(term,grant);if(!record||record.caseId!==caseId)throw Error()
      if(!live.current)return
      const url=URL.createObjectURL(new Blob([JSON.stringify(record,null,2)+'\n'],{type:'application/json;charset=utf-8'}))
      const link=document.createElement('a');link.href=url;link.download='approved-prism-record.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000)
    }catch{if(live.current)setError('The current approval, case version or access could not be confirmed. Refresh before trying again.')}
    finally{if(live.current)setBusy(false)}
  }
  return <details className="work-section"><summary>Approved private export</summary><p>Only a current named custodian approval enables download. Your copy includes your current authorized evidence view; copies require separate custody and retention. Review the scope before downloading.</p>
    {!grants.length?<p>No current export approval. Ask the PRISM custodian through Privacy rights and requests.</p>:grants.map(g=><div key={g.id}>
      <p>Approved current case version · ends {date(g.expiresAt)}</p><button className="button button--secondary" disabled={busy||checking} onClick={()=>void download(g.id)}>Download approved private copy</button></div>)}
    {error?<p role="alert">{error}</p>:null}</details>
}
type Actions={api:EvaluationsApi;term:string;checking:boolean;saved:(n:string)=>void;refresh:()=>void}
function Custody(actions:Actions){
  const [open,setOpen]=useState(false),[setup,setSetup]=useState<EvaluationSetup|null>(null),[report,setReport]=useState<EvaluationReport|null>(null)
  const [error,setError]=useState(''),[revision,setRevision]=useState(0),[chosen,setChosen]=useState<string|null>(null)
  const {api,term}=actions
  useEffect(()=>{if(!open)return;let live=true
    void Promise.all([api.setup(term),api.report(term)]).then(([s,r])=>{if(live){setSetup(s);setReport(r);setError('')}})
      .catch(()=>{if(live){setSetup(null);setReport(null);setError('Current custodian access and a verified session are required.')}})
    return()=>{live=false}
  },[api,term,open,revision,actions.checking])
  const saved=(n:string)=>{setChosen(null);setRevision(v=>v+1);actions.saved(n)}
  const current=setup?.rounds.flatMap(r=>r.cases).find(c=>c.id===chosen)
  return <details className="work-section" onToggle={e=>setOpen(e.currentTarget.open)}><summary>Custodian export controls and safe cohort report</summary>
    {open?<>{error?<p role="alert">{error}</p>:null}
      {current&&setup?<EvaluationEditor {...actions} saved={saved} edit={{kind:'grantExport',caseRecord:current,people:setup.people}} close={()=>setChosen(null)}/>:null}
      {setup?.rounds.map(r=><Panel title={r.label} key={r.id}>{r.cases.map(c=><article key={c.id}>
        <h3>{setup.people.find(p=>p.id===c.subjectId)?.name??'Current subject'}</h3>
        {!chosen?<button className="button button--secondary" onClick={()=>setChosen(c.id)}>Approve export for this case</button>:null}
        {c.exports.filter(g=>!g.revoked).map(g=><div key={g.id}><p>Export for {setup.people.find(p=>p.id===g.memberId)?.name??'Named participant'} · ends {date(g.expiresAt)}</p>
          <EvaluationAction {...actions} saved={saved} id={g.id} command={{kind:'revokeExport',term,grant:g.id,version:g.version}}
            label="Revoke export approval" notice="Export approval revoked."/></div>)}
      </article>)}</Panel>)}
      {report?<Panel title="Fixed term cohort report"><p>This reports only a lower bound of distinct subjects with current released summaries at publication. It contains no feedback themes, scores, individual rows, exact total or complementary count. No filters or drilldown are available.</p>
        <p>{report.state==='published'?'Published cohort: 5 or more distinct subjects. Frozen at '+date(report.at!):report.state==='suppressed'?
          'Withheld: the minimum cohort of five is not met. No smaller count is shown.':report.state==='not_ready'?'Unavailable until all collection windows close and their release times arrive.':'Minimum cohort met. One fixed publication is available.'}</p>
        {report.state==='ready'?<EvaluationAction {...actions} saved={saved} id="cohort-report" command={{term,kind:'report'}} label="Publish fixed cohort report"
          notice="Term cohort report published and frozen." confirm="Publish the fixed term cohort? Later changes will not produce a second or narrower report."/>:null}
      </Panel>:null}
    </>:null}
  </details>
}
