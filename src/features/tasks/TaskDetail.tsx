import {Comments} from '../comments/Comments'
import type {CommentsApi} from '../comments/api'
import{useEffect,useState}from'react'
import{Link,useParams,useRouteLoaderData}from'react-router'
import{PageHeading,Panel}from'../../components/Page'
import{LoadingState,ErrorState,EmptyState}from'../../components/FeedbackState'
import{isGuest,type WorkspaceContext}from'../auth/gateway'
import{dateLabel}from'../deliverables/DeliverableFacts'
import{TaskEditor}from'./TaskEditor'
import type{TasksApi,TaskItem}from'./api'
export function TaskDetail({api,comments}:{api:TasksApi;comments?:CommentsApi}){
 const{taskId=''}=useParams();const context=useRouteLoaderData('workspace') as WorkspaceContext;const[reload,setReload]=useState(0);const key=taskId+':'+reload+':'+('memberId'in context?context.memberId:context.guestAccessId)
 const[state,setState]=useState<{key:string;item:TaskItem|null;error:boolean}|null>(null)
 useEffect(()=>{let active=true;void Promise.resolve(api.detail?.(taskId)??null).then(item=>{if(active)setState({key,item,error:false})}).catch(()=>{if(active)setState({key,item:null,error:true})});return()=>{active=false}},[api,taskId,key])
 const current=state?.key===key?state:null;const item=current?.item
 return <><Link className="button button--secondary" to={isGuest(context)?'/shared':'/tasks'}>Back to permitted tasks</Link>{!current?<LoadingState title="Loading task"/>:current.error?<ErrorState title="Task unavailable" description="Check access or connection and reload." action={<button className="button" onClick={()=>setReload(reload+1)}>Reload task</button>}/>:!item?<EmptyState title="Task cannot be shown" description="The address is unavailable or your access changed. No private details are shown."/>:<><PageHeading title={item.title} description="Task completion is separate from finance, publicity and deliverable acceptance."/><Panel title="Task details"><p>{item.summary}</p><p>Saved version {item.version} · Updated {dateLabel(item.updatedAt,null)}</p>{item.archivedAt?<p>This task is archived.</p>:null}<p>Completion rule: {item.taskType.replaceAll('_',' ')}. {item.taskType==='governed'?'Governed completion stays blocked until authoritative approvals are available.':item.taskType==='review_required'?'An independent scoped manager must review the final evidence.':'Checklist completion and evidence are required.'}</p><p>Owner: {item.ownerName} · Assignee: {item.assigneeName??'Unassigned'} · Status: {item.state.replaceAll('_',' ')}</p><p>Target: {dateLabel(item.dueAt,item.dueOn)}{item.overdue?' · Overdue':''} · Original: {dateLabel(item.originalDueAt,item.originalDueOn)}</p>{item.blockedReason?<p>Blocked: {item.blockedReason}</p>:null}<p className="record-text">{item.body}</p>{item.evidence?<p className="record-text">Evidence: {item.evidence}</p>:null}<ul>{item.checklist.map(c=><li key={c.id}>{c.done?'Complete: ':'Pending: '}{c.text}</li>)}</ul></Panel><button className="button button--secondary" onClick={()=>setReload(reload+1)}>Reload task (discard unsaved edits)</button>{!isGuest(context)&&item.canEdit?<Panel title="Edit task"><TaskEditor key={key+':'+item.version} api={api} termId={context.termId} item={item} onSaved={()=>setReload(reload+1)}/></Panel>:null}{comments?<Comments api={comments} workId={taskId}/>:null}</>}</>
}
