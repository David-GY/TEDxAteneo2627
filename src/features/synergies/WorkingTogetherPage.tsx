import {useEffect,useState} from 'react'
import {Link,useRouteLoaderData,useSearchParams} from 'react-router'
import {PageHeading,Panel} from '../../components/Page'
import {EmptyState,ErrorState,LoadingState} from '../../components/FeedbackState'
import type {WorkspaceContext} from '../auth/gateway'
import {dateLabel} from '../deliverables/DeliverableFacts'
import type {SynergiesApi,SynergyList} from './api'

export function CommitteeWork({api,termId,view,parentId}:{api:SynergiesApi;termId:string;view:string;parentId?:string}){
 const [params,setParams]=useSearchParams(),[reload,setReload]=useState(0)
 const n=Number(params.get('page')??1),page=Number.isInteger(n)&&n>=1&&n<=10000?n:1,key=termId+view+parentId+page+reload
 const [state,setState]=useState<{key:string;result:SynergyList|null;error:boolean}|null>(null)
 useEffect(()=>{let live=true;void api.list(termId,view,parentId,page).then(result=>{if(live)setState({key,result,error:false})}).catch(()=>{if(live)setState({key,result:null,error:true})});return()=>{live=false}},[api,termId,view,parentId,page,key])
 const current=state?.key===key?state:null
 return <><button className="button button--secondary" onClick={()=>setReload(n=>n+1)}>Refresh committee work</button>{!current?<LoadingState title="Loading committee work"/>:current.error?<ErrorState title="Committee work unavailable" description="Check access or connection, then refresh."/>:!current.result?<EmptyState title="Committee work cannot be shown" description="No access to this scope is available."/>:<>
 {!current.result.agreements.length&&!current.result.contributions.length?<EmptyState title="No permitted records on this page" description="Negotiations require current participating head authority. Assigned contributions require independent task access."/>:null}
 <ul className="guest-list">{current.result.agreements.map(a=><li key={a.id}><h3><Link to={'/working-together/'+a.id}>{a.terms.output}</Link></h3><p>{a.interface?.requesterUnitName} → {a.interface?.receiverUnitName} · {a.state} · Revision {a.revision}</p><p>Proposed deadline: {dateLabel(null,a.terms.dueOn)} · {a.interface?.pendingWith?`Waiting on ${a.interface.pendingWith==='requester'?a.interface.requesterUnitName:a.interface.receiverUnitName} head`:'No pending response'}</p>{a.activeRevision?<p>Active agreed revision: {a.activeRevision} · Agreed deadline: {dateLabel(null,a.revisions.find(r=>r.revision===a.activeRevision)?.dueOn??null)}. {a.activeRevision!==a.revision?'Earlier accepted work remains active.':''}</p>:null}</li>)}</ul>
 <ul className="guest-list">{current.result.contributions.map(c=><li key={c.id}><h3><Link to={'/tasks/'+c.id}>{c.output}</Link></h3><p>Agreed deadline: {dateLabel(null,c.dueOn)} · Owner: {c.ownerName} · {c.task.state.replaceAll('_',' ')}</p><p className="record-text">Criteria: {c.criteria}</p><p>Effort: {c.effort}</p><p>{c.task.dependencyBlocked?'Blocked by a required predecessor. Open assigned work for the next step.':'No unfinished required predecessor currently blocks this task; other approval rules still apply.'}</p><p>Accepted revision {c.revision} · <Link to={'/tasks/'+c.id}>Open assigned work</Link></p></li>)}</ul>
 <nav className="auth-actions" aria-label="Committee work pages"><button className="button button--secondary" disabled={page===1} onClick={()=>setParams(p=>{p.set('page',String(page-1));return p})}>Previous page</button><span>Page {page}</span><button className="button button--secondary" disabled={!current.result.hasMore} onClick={()=>setParams(p=>{p.set('page',String(page+1));return p})}>Next page</button></nav>
 </>}</>
}
export function WorkingTogetherPage({api}:{api:SynergiesApi}){
 const context=useRouteLoaderData('workspace') as WorkspaceContext,[params,setParams]=useSearchParams(),view=['outgoing','incoming','contributions'].includes(params.get('view')??'')?params.get('view')!:'outgoing'
 return <><PageHeading title="Working together" description="One agreement, shared terms and named contribution owners."/><p><Link className="button" to="/deliverables">Request help from a deliverable</Link></p><div className="deliverable-editor form-field"><label htmlFor="synergy-view">Committee work view</label><select id="synergy-view" value={view} onChange={e=>setParams({view:e.target.value})}><option value="outgoing">Outgoing agreements</option><option value="incoming">Incoming agreements</option><option value="contributions">Contributions / assigned work</option></select></div><Panel title="Agreements and contributions"><CommitteeWork key={context.termId+('memberId'in context?context.memberId:context.guestAccessId)} api={api} termId={context.termId} view={view}/></Panel></>
}
