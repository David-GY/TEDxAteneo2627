import {useEffect,useState} from 'react'
import {useRouteLoaderData} from 'react-router'
import type {WorkspaceContext} from '../auth/gateway'
import {PageHeading,Panel} from '../../components/Page'
import {LoadingState,ErrorState,EmptyState} from '../../components/FeedbackState'
import {dateLabel} from '../deliverables/DeliverableFacts'
import type {TasksApi,OwnedTask} from './api'
export function TasksPage({api}:{api:TasksApi}){
  const context=useRouteLoaderData('workspace') as WorkspaceContext
  const[page,setPage]=useState(1);const[reload,setReload]=useState(0)
  const key=context.termId+':'+('memberId' in context?context.memberId:context.guestAccessId)+':'+page+':'+reload
  const[state,setState]=useState<{key:string;items:OwnedTask[];total:number;error:boolean}|null>(null)
  useEffect(()=>{let active=true;void api.read(context.termId,page).then(r=>{if(active)setState({key,...r,error:false})}).catch(()=>{if(active)setState({key,items:[],total:0,error:true})});return()=>{active=false}},[api,context.termId,page,key])
  const current=state?.key===key?state:null
  return <><PageHeading title="My tasks" description="Owned task records"/><p>This read-only checkpoint shows records you own. Assignment, collaborators, checklist and progress editing are not connected yet. Task completion never grants finance or publicity approval.</p><button className="button button--secondary" onClick={()=>setReload(reload+1)}>Reload owned tasks</button>
    {!current?<LoadingState title="Loading owned tasks"/>:current.error?<ErrorState title="Tasks unavailable" description="Check access or connection and reload." action={<button className="button" onClick={()=>setReload(reload+1)}>Try again</button>}/>:<><p role="status">{current.total} owned task records · Page {page}</p>{current.items.length?current.items.map(t=><Panel key={t.id} title={t.title}><p>{t.summary}</p><p>Category: {t.category.replaceAll('_',' ')} · Target: {dateLabel(t.dueAt,t.dueOn)}{t.overdue?' · Overdue':''}</p></Panel>):<EmptyState title="No owned tasks on this page" description="Only your permitted owned records are counted. Assignment and authoring remain pending."/>}<nav className="auth-actions" aria-label="Owned task pages"><button className="button button--secondary" disabled={page<=1} onClick={()=>setPage(page-1)}>Previous page</button><button className="button button--secondary" disabled={page*20>=current.total} onClick={()=>setPage(page+1)}>Next page</button></nav></>}
  </>
}
