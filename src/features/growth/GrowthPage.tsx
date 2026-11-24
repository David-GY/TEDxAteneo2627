import {useCallback,useEffect,useRef,useState} from 'react'
import {Link,useRouteLoaderData,useSearchParams} from 'react-router'
import {EmptyState,ErrorState,LoadingState} from '../../components/FeedbackState'
import {PageHeading,Panel} from '../../components/Page'
import type {WorkspaceContext} from '../auth/gateway'
import {forgetRecordDrafts} from '../auth/draftScope'
import {privateAppointmentIcs} from '../calendar/ics'
import {categoryLabels,type Assignment,type Assignments,type Checkin,type Goal,type GrowthApi,type GrowthWorkspace,type Relationship} from './api'
import {GoalProgress,GrowthAction,GrowthEditor,type GrowthEdit} from './GrowthEditor'
import './growth.css'

const dates=new Intl.DateTimeFormat('en-PH',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Manila'})
const during=(start:string,end:string)=>dates.formatRange(new Date(start),new Date(end))+' (Manila)'
const states={scheduled:'Scheduled',completed:'Completed',missed:'Missed',cancelled:'Cancelled',ended:'Mentorship ended'}
type Choice={kind:'goal';id:string|null}|{kind:'share'|'schedule'|'reschedule'|'note';id:string}
type Actions={api:GrowthApi;term:string;checking:boolean;refresh:()=>void;saved:(notice:string)=>void}

function resolveEdit(w:GrowthWorkspace,q:Choice):GrowthEdit|null{
  if(!w.editable)return null
  const goal=w.goals.find(g=>g.id===q.id&&g.own)
  if(q.kind==='goal')return q.id===null||goal?{kind:'goal',goal}:null
  if(q.kind==='share')return goal?{kind:'share',goal,choices:w.relationships.filter(r=>!r.asMentor&&r.state==='active')}:null
  if(q.kind==='schedule'){
    const relationship=w.relationships.find(r=>r.id===q.id&&r.state==='active')
    return relationship?{kind:'schedule',relationship}:null
  }
  const checkin=w.checkins.find(c=>c.id===q.id&&c.canAct)
  if(!checkin)return null
  if(q.kind==='note')return {kind:'note',checkin}
  const relationship=w.relationships.find(r=>r.id===checkin.relationship&&r.state==='active')
  return relationship?{kind:'schedule',relationship,checkin}:null
}

export function GrowthLink({api,term}:{api:GrowthApi;term:string}){
  const [search]=useSearchParams(),[enabled,setEnabled]=useState<string|null>(null)
  useEffect(()=>{
    let live=true,sequence=0
    const check=()=>{
      const current=++sequence
      void api.enabled(term).then(active=>{if(live&&current===sequence)setEnabled(active?term:null)})
        .catch(()=>{if(live&&current===sequence)setEnabled(null)})
    }
    check();window.addEventListener('focus',check)
    return()=>{live=false;window.removeEventListener('focus',check)}
  },[api,term])
  return enabled===term?<Link className="button button--secondary" to={'/mentoring'+(search.has('term')?'?term='+term:'')}>Goals and mentoring</Link>:null
}

export function GrowthPage({api}:{api:GrowthApi}){
  const workspace=useRouteLoaderData('workspace')as WorkspaceContext
  if(!('memberId'in workspace))return <EmptyState title="Goals and mentoring unavailable" description="Current core workspace access is required."/>
  return <GrowthBody key={workspace.termId+':'+workspace.memberId} term={workspace.termId} api={api}/>
}

function GrowthBody({term,api}:{term:string;api:GrowthApi}){
  const [workspace,setWorkspace]=useState<GrowthWorkspace|null>(null)
  const [checking,setChecking]=useState(true),[failed,setFailed]=useState(false)
  const [choice,setChoice]=useState<Choice|null>(null),[notice,setNotice]=useState('')
  const generation=useRef(0),activeChoice=useRef<Choice|null>(null),lastWorkspace=useRef<GrowthWorkspace|null>(null)
  const editor=useRef<HTMLDivElement>(null),receipt=useRef<HTMLParagraphElement>(null)
  const load=useCallback(async()=>{
    const current=++generation.current
    setChecking(true);setFailed(false)
    try{
      const next=await api.read(term)
      if(generation.current!==current)return
      const old=lastWorkspace.current
      if(old){
        const visible=new Set(next?[...next.goals,...next.checkins,...next.relationships].map(r=>r.id):[])
        for(const record of [...old.goals,...old.checkins,...old.relationships])if(!visible.has(record.id))forgetRecordDrafts(record.id)
      }
      if(activeChoice.current&&(!next||!resolveEdit(next,activeChoice.current))){
        forgetRecordDrafts(activeChoice.current.id??'new-goal')
        activeChoice.current=null;setChoice(null)
        setNotice(next?'The current assignment or sharing access changed.':'')
      }
      if(!next)setNotice('')
      lastWorkspace.current=next
      setWorkspace(next)
    }catch{if(generation.current===current)setFailed(true)}
    finally{if(generation.current===current)setChecking(false)}
  },[api,term])
  useEffect(()=>{
    const check=()=>{if(document.visibilityState!=='hidden')void load()}
    check();window.addEventListener('focus',check);document.addEventListener('visibilitychange',check)
    const timer=setInterval(check,30000)
    return()=>{generation.current++;clearInterval(timer);window.removeEventListener('focus',check);document.removeEventListener('visibilitychange',check)}
  },[load])
  useEffect(()=>{
    const expires=workspace?.relationships.filter(r=>r.state==='active').map(r=>Date.parse(r.endsAt)).sort((a,b)=>a-b)[0]
    if(!expires)return
    const delay=Math.min(Math.max(expires-Date.now()+50,50),2147483647)
    const timer=setTimeout(()=>void load(),delay)
    return()=>clearTimeout(timer)
  },[load,workspace])
  useEffect(()=>{if(choice)editor.current?.focus()},[choice])
  useEffect(()=>{if(notice)receipt.current?.focus()},[notice])

  function open(q:Choice){setNotice('');activeChoice.current=q;setChoice(q)}
  function close(){activeChoice.current=null;setChoice(null)}
  function saved(message:string){close();setNotice(message);void load()}
  const actions={api,term,checking,refresh:()=>void load(),saved}
  const edit=workspace&&choice?resolveEdit(workspace,choice):null
  const own=workspace?.goals.filter(g=>g.own)??[],shared=workspace?.goals.filter(g=>!g.own)??[]
  const live=workspace?.relationships.filter(r=>r.state==='active'&&!r.asMentor)??[]
  const next=workspace?.checkins.find(c=>c.state==='scheduled'&&Date.parse(c.endsAt)>Date.now())
  return <div className="growth">
    <PageHeading title="Goals and mentoring" description={workspace?.termLabel}/>
    {failed?<ErrorState title="Learning workspace unavailable" description="Check your connection or current access. Your entries are kept in memory."
      action={<button className="button" onClick={()=>void load()}>Check access again</button>}/>:null}
    {!workspace&&checking?<LoadingState title="Checking learning workspace access"/>:null}
    {!workspace&&!checking&&!failed?<EmptyState title="Goals and mentoring unavailable" description="For mentoring arrangements, ask your permitted process contact."
      action={<Link className="button button--secondary" to="/people">Find a contact</Link>}/>:null}
    {workspace?<div hidden={failed}>
      <p>Set a private goal for yourself or share one with a current mentor. Check-ins are optional.</p>
      {next?<p><strong>Next check-in</strong> · {during(next.startsAt,next.endsAt)}</p>:null}
      {notice?<p ref={receipt} tabIndex={-1} role="status">{notice}</p>:null}
      {checking?<p role="status">Checking current mentoring and sharing access…</p>:null}
      <div inert={checking}>
        {edit?<div ref={editor} tabIndex={-1}><GrowthEditor key={choice?.kind+':'+choice?.id} edit={edit}
          {...actions} close={close}/></div>:null}
        <Panel title="My goals">
          {!own.length?<p>Start with one small goal. You can keep it private and add a target when you are ready.</p>:null}
          {workspace.editable&&!edit?<button className="button" onClick={()=>open({kind:'goal',id:null})}>Add a personal goal</button>:null}
          <ul className="growth-list">{own.map(g=><li key={g.id}>
            <GoalDetails goal={g} relationship={workspace.relationships.find(r=>r.id===g.sharedWith)}/>
            {workspace.editable?<GoalProgress goal={g} {...actions} checking={checking||!!edit}/>:null}
            {!edit?<div className="auth-actions">
              {workspace.editable?<button className="button button--secondary" onClick={()=>open({kind:'goal',id:g.id})}>Edit goal details</button>:null}
              {workspace.editable&&live.length?<button className="button button--secondary" onClick={()=>open({kind:'share',id:g.id})}>
                {g.sharedWith?'Change goal sharing':'Share with a mentor'}</button>:null}
              {g.hasSharingRecord?<GrowthAction {...actions} command={{kind:'share',term,id:g.id,version:g.version,relationship:null}}
                label="Stop sharing goal" notice="Sharing stopped. Your goal is still saved."/>:null}
            </div>:null}
          </li>)}</ul>
        </Panel>
        {shared.length?<Panel title="Goals shared by assigned mentees"><ul className="growth-list">{shared.map(g=><li key={g.id}>
          <GoalDetails goal={g}/><p>{g.progress}% progress · Shared by {g.learner}</p>
        </li>)}</ul></Panel>:null}
        <Panel title="Mentoring assignments">
          {!workspace.relationships.length?<p>When a mentor is approved, you can choose whether to join here. <Link className="button button--secondary" to="/people">Find a contact</Link></p>:null}
          <ul className="growth-list">{workspace.relationships.map(r=><li key={r.id}>
            <h3>{r.asMentor?'Mentee '+r.mentee:'Mentor '+r.mentor}</h3>
            <p>{r.state==='offered'?'Awaiting your consent':r.state==='upcoming'?'Accepted · starts later':r.state==='active'?'Active assignment':'Assignment ended'} · {during(r.startsAt,r.endsAt)}</p>
            {!edit?<div className="auth-actions">
              {r.state==='offered'&&workspace.editable?<div><p>Joining lets both participants arrange check-ins. You choose each goal to share.</p>
                <GrowthAction {...actions} command={{kind:'consent',term,id:r.id,version:r.version,accept:true}}
                  label="Join mentoring" notice="Mentoring accepted."/></div>:null}
              {r.state==='active'&&workspace.editable?<button className="button button--secondary" onClick={()=>open({kind:'schedule',id:r.id})}>
                Schedule a check-in</button>:null}
              {r.state!=='ended'?<GrowthAction {...actions} command={{kind:'consent',term,id:r.id,version:r.version,accept:false}}
                label={r.state==='offered'?'Decline assignment':'End mentoring assignment'}
                notice="Assignment ended." confirm="End this assignment and remove shared mentoring access? You keep your personal goals."/>:null}
            </div>:null}
          </li>)}</ul>
        </Panel>
        <Panel title="Private check-ins" id="check-ins">
          {!workspace.checkins.length?<p>Check-ins appear here after you schedule one with a current mentor. You can use this page with your own calendar or on its own.</p>:null}
          <ul className="growth-list">{workspace.checkins.map(c=><li key={c.id}>
            <CheckinDetails checkin={c} relationship={workspace.relationships.find(r=>r.id===c.relationship)}
              {...actions} open={edit?undefined:open}/>
          </li>)}</ul>
        </Panel>
        {workspace.canManage?<MentoringAssignments {...actions}/>:null}
        <details className="work-section"><summary>Who can access learning records?</summary>
          <p>Goal access follows the audience shown on each goal. Check-in history stays available to the learner. Authorized database operators can access stored records for custody and recovery.</p>
          <Link className="button button--secondary" to="/privacy">Privacy information</Link>
        </details>
        <details className="work-section"><summary>Export my learning record</summary>
          <p>Download a private JSON file with your goals and notes you wrote.</p>
          <DownloadAction label="Download my learning record" disabled={checking}
            download={async()=>({name:'my-learning-record.json',type:'application/json;charset=utf-8',data:JSON.stringify(await api.exportOwn(term),null,2)+'\n'})}/>
        </details>
      </div>
      <button className="button button--secondary" disabled={checking} onClick={()=>void load()}>Refresh learning workspace</button>
    </div>:null}
  </div>
}

function GoalDetails({goal,relationship}:{goal:Goal;relationship?:Relationship}){
  return <>
    <h3>{goal.title}</h3>
    <p>{categoryLabels[goal.category]}{goal.own?' · '+(relationship?'Shared with '+relationship.mentor:'Private to you in the workspace'):''}</p>
    {goal.target?<p className="record-text">{goal.target}</p>:null}
  </>
}

function CheckinDetails({checkin:c,relationship:r,open,...actions}:Actions&{
  checkin:Checkin;relationship?:Relationship;open?:((c:Choice)=>void)
}){
  const now=Date.now(),date=Date.parse(c.startsAt),scheduled=c.state==='scheduled'
  return <>
    <h3>{c.title??'Mentoring check-in'}</h3>
    <p>{states[c.state]} · {during(c.startsAt,c.endsAt)}</p>
    {r?<p>With {r.asMentor?r.mentee:r.mentor}</p>:null}
    {open&&c.canAct?<div className="auth-actions">
      {c.state!=='cancelled'?<button className="button button--secondary" onClick={()=>open({kind:'note',id:c.id})}>Add a check-in note</button>:null}
      {scheduled&&date>now?<button className="button button--secondary" onClick={()=>open({kind:'reschedule',id:c.id})}>Change check-in</button>:null}
      {scheduled?(['completed','missed','cancelled'] as const).filter(action=>action==='cancelled'||
        action==='completed'&&date<=now||action==='missed'&&Date.parse(c.endsAt)<=now).map(action=><GrowthAction key={action} {...actions}
        command={{kind:'checkin',term:actions.term,id:c.id,version:c.version,relationship:c.relationship,action,startsAt:null,endsAt:null,title:null}}
        label={action==='completed'?'Mark completed':action==='missed'?'Mark missed':'Cancel check-in'}
        notice={'Check-in '+action+'.'} confirm={action==='cancelled'?'Cancel this private check-in?':undefined}/>):null}
    </div>:null}
    {c.notes.length?<details className="work-section"><summary>Check-in notes</summary>
      <ul className="growth-list">{c.notes.map(n=><li key={n.id}>
        <strong>{n.author}</strong> · {dates.format(new Date(n.at))}
        {n.body?<p className="record-text">{n.body}</p>:null}
        {n.nextAction?<p className="record-text">Next action · {n.nextAction}</p>:null}
      </li>)}</ul></details>:null}
    {c.canExport?<details className="work-section"><summary>Private calendar copy</summary>
      <p>The file includes the time and the label “Private appointment”. Imported copies stay in your calendar. Future changes are handled here.</p>
      <DownloadAction label="Download private calendar copy" disabled={actions.checking}
        download={async()=>({name:'private-appointment.ics',type:'text/calendar;charset=utf-8',
          data:privateAppointmentIcs(await actions.api.calendar(actions.term,c.id,c.version))})}/>
    </details>:null}
  </>
}

function DownloadAction({label,disabled,download}:{label:string;disabled:boolean;download:()=>Promise<{name:string;type:string;data:string}>}){
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),mounted=useRef(true)
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false}},[])
  async function prepare(){
    setBusy(true);setError('')
    try{
      const file=await download()
      if(!mounted.current)return
      const url=URL.createObjectURL(new Blob([file.data],{type:file.type})),link=document.createElement('a')
      link.href=url;link.download=file.name;link.click();setTimeout(()=>URL.revokeObjectURL(url),1000)
    }catch{if(mounted.current)setError('Current access or version could not be confirmed. Refresh and try again.')}
    finally{if(mounted.current)setBusy(false)}
  }
  return <>{error?<p role="alert">{error}</p>:null}
    <button className="button button--secondary" disabled={busy||disabled} onClick={()=>void prepare()}>{label}</button></>
}

function MentoringAssignments(actions:Actions){
  const [open,setOpen]=useState(false),[data,setData]=useState<Assignments|null>(null),[failed,setFailed]=useState(false)
  const [version,setVersion]=useState(0),[choice,setChoice]=useState<Assignment|true|null>(null)
  const {api,term}=actions
  useEffect(()=>{
    if(!open)return
    let live=true
    void api.assignments(term).then(value=>{if(live){setData(value);setFailed(false)}})
      .catch(()=>{if(live){setData(null);setFailed(true)}})
    return()=>{live=false}
  },[api,term,open,version])
  function saved(message:string){setChoice(null);setVersion(v=>v+1);actions.saved(message)}
  const latest=data&&typeof choice==='object'&&choice?data.assignments.find(r=>r.id===choice.id):undefined
  return <details className="work-section" onToggle={event=>setOpen(event.currentTarget.open)}>
    <summary>Manage mentor assignments</summary>
    {open?<Panel title="Approved mentoring assignments">
      {failed?<p role="alert">Check your coordinator access and verified session.</p>:null}
      <button className="button button--secondary" onClick={()=>setVersion(v=>v+1)}>Refresh assignments</button>
      {data?<><p>Approval opens a voluntary offer. Replacement closes the previous assignment and starts a new consent decision.</p>
        {choice?<GrowthEditor key={latest?.id??'new'} {...actions} edit={{kind:'assignment',data,previous:latest}}
          close={()=>setChoice(null)} saved={saved} refresh={()=>{setVersion(v=>v+1);actions.refresh()}}/>:
          <button className="button" onClick={()=>setChoice(true)}>Approve a new assignment</button>}
        <ul className="growth-list">{data.assignments.map(r=><li key={r.id}>
          <strong>{r.mentee} · {r.mentor}</strong><p>{r.state} · {during(r.startsAt,r.endsAt)}</p>
          {!choice?<div className="auth-actions"><button className="button button--secondary" onClick={()=>setChoice(r)}>Replace {r.mentee}’s mentor</button>
            {!r.revoked?<GrowthAction {...actions} command={{kind:'consent',term,id:r.id,version:r.version,accept:false}}
              label="End assignment" notice="Assignment ended." confirm="End this mentoring assignment and remove its sharing access?" saved={saved}/>:null}
          </div>:null}
        </li>)}</ul>
      </>:!failed?<LoadingState title="Checking assignment authority"/>:null}
    </Panel>:null}
  </details>
}
