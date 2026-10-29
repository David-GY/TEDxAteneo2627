import {WorkReference} from '../work-references/WorkReference'
import{useEffect,useState}from'react'
import{Link,useNavigate,useRouteLoaderData,useSearchParams}from'react-router'
import type{WorkspaceContext}from'../auth/gateway'
import{PageHeading,Panel}from'../../components/Page'
import{LoadingState,ErrorState,EmptyState}from'../../components/FeedbackState'
import{dateLabel}from'../deliverables/DeliverableFacts'
import{TaskEditor}from'./TaskEditor'
import type{TasksApi,OwnedTask,TaskSummary}from'./api'
export function TasksPage({api}:{api:TasksApi}){
 const context=useRouteLoaderData('workspace') as WorkspaceContext;const navigate=useNavigate();const[params,setParams]=useSearchParams();const view=['assigned','created','watching','overdue','unit'].includes(params.get('view')??'')?params.get('view')!:'assigned';const parsed=Number(params.get('page')??1);const page=Number.isInteger(parsed)&&parsed>=1&&parsed<=10000?parsed:1
 const[reload,setReload]=useState(0);const key=context.termId+':'+('memberId'in context?context.memberId:context.guestAccessId)+':'+page+':'+view+':'+reload
 const[state,setState]=useState<{key:string;items:(TaskSummary|OwnedTask)[];total:number;error:boolean}|null>(null)
 useEffect(()=>{let active=true;void(api.list?api.list(context.termId,page,view):api.read(context.termId,page)).then(r=>{if(active)setState({key,...r,error:false})}).catch(()=>{if(active)setState({key,items:[],total:0,error:true})});return()=>{active=false}},[api,context.termId,page,view,key])
 const current=state?.key===key?state:null;const move=(p:number)=>setParams({view,page:String(p)})
 return <><PageHeading title="My tasks" description="Assigned work, shared collaboration and next actions"/><p>Accepted contributions use their canonical assigned tasks here. Task completion never grants finance or publicity approval.</p><button className="button button--secondary" onClick={()=>setReload(reload+1)}>Reload tasks</button>
 {api.execute?<details className="panel"><summary>Create task</summary><TaskEditor api={api} termId={context.termId} onSaved={id=>void navigate('/tasks/'+id)}/></details>:null}
 <div className="deliverable-editor form-field"><label htmlFor="task-view">Task view</label><select id="task-view" value={view} onChange={e=>setParams({view:e.target.value})}>{[['assigned','Assigned to me'],['created','Created by me'],['watching','Collaborating / shared'],['overdue','My overdue work'],['unit','Managed committee work']].map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></div>
 {!current?<LoadingState title="Loading tasks"/>:current.error?<ErrorState title="Tasks unavailable" description="Check access or connection and reload." action={<button className="button" onClick={()=>setReload(reload+1)}>Try again</button>}/>:<><p role="status">{current.total} permitted task records · Page {page}</p>{current.items.length?current.items.map(t=><Panel key={t.id} title={t.title}><WorkReference compact reference={t.reference} id={t.id} kind="task"/><p>{t.summary}</p><p>Assignee: {'assigneeName'in t?t.assigneeName??'Unassigned':'Not recorded'}</p><p>Status: {'state'in t?t.state.replaceAll('_',' '):t.category} · Target: {dateLabel(t.dueAt,t.dueOn)}{t.overdue?' · Overdue':''}</p><Link className="button button--secondary" to={'/tasks/'+t.id}>Open task</Link></Panel>):<EmptyState title="No tasks on this page" description="Only permitted tasks in this view are counted. Choose another view or contact the accountable owner."/>}<nav className="auth-actions" aria-label="Task pages"><button className="button button--secondary" disabled={page<=1} onClick={()=>move(page-1)}>Previous page</button><button className="button button--secondary" disabled={page*20>=current.total} onClick={()=>move(page+1)}>Next page</button></nav></>}
 </>
}
