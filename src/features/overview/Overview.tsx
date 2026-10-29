import {WorkReference} from '../work-references/WorkReference'
import {useEffect,useState} from 'react'
import {Link,useRouteLoaderData} from 'react-router'
import {PageHeading,Panel} from '../../components/Page'
import {LoadingState,ErrorState,EmptyState} from '../../components/FeedbackState'
import type {WorkspaceContext} from '../auth/gateway'
import {dateLabel} from '../deliverables/DeliverableFacts'
import type {OverviewApi,OverviewResult} from './api'
export function Overview({api}:{api:OverviewApi}){
 const context=useRouteLoaderData('workspace')as WorkspaceContext,subject='memberId'in context?context.memberId:context.guestAccessId
 return <OverviewBody key={context.termId+subject} api={api} termId={context.termId}/>
}
function OverviewBody({api,termId}:{api:OverviewApi;termId:string}){
 const[result,setResult]=useState<OverviewResult|null>(null),[error,setError]=useState(false),[reload,setReload]=useState(0)
 useEffect(()=>{let live=true;void api.read(termId).then(r=>{if(live){setResult(r);setError(false)}}).catch(()=>{if(live){setResult(null);setError(true)}});return()=>{live=false}},[api,termId,reload])
 useEffect(()=>{const refresh=()=>{setResult(null);setReload(n=>n+1)},visible=()=>{if(document.visibilityState==='visible')refresh()};window.addEventListener('focus',refresh);document.addEventListener('visibilitychange',visible);return()=>{window.removeEventListener('focus',refresh);document.removeEventListener('visibilitychange',visible)}},[])
 return <><PageHeading title="Overview" description="Your next actions and work waiting on someone else."/><p>Open a work title below to act. Task completion and independent approval stay separate.</p><button className="button button--secondary" onClick={()=>{setResult(null);setReload(n=>n+1)}}>Refresh overview</button>
 {error?<ErrorState title="Overview unavailable" description="Check access or connection, then refresh the overview."/>:!result?<LoadingState title="Loading next actions"/>:<>
 <p>Refreshed {dateLabel(result.refreshedAt,null)}. Dates and overdue cutoff use Manila time.{result.hasMore?' Showing the first 50 permitted records; open Department inbox, My tasks or Core deliverables for more.':''}</p>
 {(['actionable','waiting']as const).map(lane=>{const rows=result.items.filter(i=>i.lane===lane);return <Panel key={lane} title={lane==='actionable'?`Who is waiting on you · ${rows.length}`:`Waiting on someone else · ${rows.length}`}>
 <p>{lane==='actionable'?'Actions assigned to you or owned outcomes you can advance.':'Blocked or submitted work needing follow-up or independent review. Reviewers are not invented when no assignment exists.'}</p>
 {rows.length===0?<EmptyState title={lane==='actionable'?'No next actions in this view':'No waiting work in this view'} description="Only current permitted records are counted." action={<Link className="button button--secondary" to="/resources">Resources & Start Here</Link>}/>:<ul className="guest-list">{rows.map(i=><li key={i.source+':'+i.id}><h3><Link to={(i.source==='review'?'/reviews/'+i.termId+'/':i.source==='request'?'/requests/'+i.termId+'/':i.source==='task'?'/tasks/':i.source==='handoff'?'/working-together/handoffs/':'/deliverables/')+i.id}>{i.title}</Link></h3>{i.source==='task'||i.source==='deliverable'?<WorkReference compact reference={i.reference} id={i.id} kind={i.source}/>:null}<p>Owner: {i.owner} · Committee: {i.committee??'Not assigned'}</p><p>Next action: {i.action} · Next person: {i.person}</p>{i.source==='review'||i.source==='request'?<p>Requested: {dateLabel(null,i.requestedOn??null)} · Accepted: {i.dueOn?dateLabel(null,i.dueOn):'Not agreed'}{i.overdue?' · Accepted date overdue':''} · {i.state.replaceAll('_',' ')}</p>:<p>Due: {dateLabel(i.dueAt,i.dueOn)} · {i.overdue?'Overdue':i.dueOn||i.dueAt?'Due date recorded':'No target recorded'} · {i.state.replaceAll('_',' ')}</p>}</li>)}</ul>}</Panel>})}
 </>}
 <p><Link to="/reviews">Department inbox</Link> · <Link to="/tasks">My tasks</Link> · <Link to="/deliverables">Core deliverables</Link> · <Link to="/working-together?view=contributions">Contributions / assigned work</Link> · <Link to="/people">Find a permitted contact</Link></p></>
}
