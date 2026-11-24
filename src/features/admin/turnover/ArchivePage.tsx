import {useCallback,useEffect,useRef,useState} from 'react'
import {Link,useParams,useRouteLoaderData,useSearchParams} from 'react-router'
import {PageHeading,Panel} from '../../../components/Page'
import {EmptyState,ErrorState,LoadingState} from '../../../components/FeedbackState'
import type {WorkspaceContext} from '../../auth/gateway'
import type {ArchivedWork,ArchivePage as ArchiveResult,TurnoverApi} from './api'
import './turnover.css'

export const archivePath=(term:string,id?:string)=>'/archive'+(id?'/'+id:'')+'?term='+encodeURIComponent(term)
export function ArchivePage({api}:{api:TurnoverApi}){
  const context=useRouteLoaderData('workspace')as WorkspaceContext,{archivedWorkId}=useParams()
  if(!('memberId'in context))return <EmptyState title="Archive unavailable" description="Current core workspace access is required."/>
  return <ArchiveBody key={context.memberId+context.termId+archivedWorkId} api={api} term={context.termId} id={archivedWorkId}/>
}
function ArchiveBody({api,term,id}:{api:TurnoverApi;term:string;id?:string}){
  const [search]=useSearchParams(),pageValue=Number(search.get('page')??1),page=Number.isSafeInteger(pageValue)&&pageValue>0?pageValue:1
  const [result,setResult]=useState<ArchiveResult|null>(null),[record,setRecord]=useState<ArchivedWork|null>(null)
  const [checking,setChecking]=useState(true),[failed,setFailed]=useState(false),sequence=useRef(0)
  const load=useCallback(async()=>{
    const current=++sequence.current;setChecking(true);setFailed(false)
    // Rechecking hides retained content immediately, including on denied/error paths.
    setRecord(null);setResult(null)
    try{const next=id?await api.record(term,id):await api.archive(term,page)
      if(current===sequence.current){if(id)setRecord(next as ArchivedWork|null);else setResult(next as ArchiveResult)}}
    catch{if(current===sequence.current)setFailed(true)}finally{if(current===sequence.current)setChecking(false)}
  },[api,term,id,page])
  useEffect(()=>{
    const check=()=>{if(document.visibilityState!=='hidden')void load()};check()
    window.addEventListener('focus',check);document.addEventListener('visibilitychange',check)
    const timer=setInterval(check,30000)
    return()=>{sequence.current++;clearInterval(timer);window.removeEventListener('focus',check);document.removeEventListener('visibilitychange',check)}
  },[load])
  return <div className="turnover">
    <PageHeading title={id?'Archived work':'Work archive'} description="Records explicitly handed over to you from a closed term."/>
    <div className="auth-actions"><Link className="button button--secondary" to={'/?term='+term}>Overview</Link>
      {id?<Link className="button button--secondary" to={archivePath(term)}>Work archive</Link>:null}
      <button className="button button--secondary" disabled={checking} onClick={()=>void load()}>Refresh current access</button></div>
    {checking?<LoadingState title="Checking archive access"/>:null}
    {failed?<ErrorState title="Archive could not be checked" description="Check your connection and current access, then refresh. Previously loaded records are hidden."/>:null}
    {!checking&&!failed&&id?(record?<Panel title={record.title}>
      <ArchiveFacts record={record}/><p className="record-text">{record.body}</p>
      <p>This is the retained record from {record.sourceTerm}. For a correction, contact the accountable handover custodian.</p>
    </Panel>:<EmptyState title="Archived record unavailable" description="You may not have a current handover grant for this record. Ask the named handover custodian to check your scope."/>):null}
    {!checking&&!failed&&!id&&result?<>
      {!result.items.length?<EmptyState title="No archived work on this page" description="Only records explicitly handed over to you appear here. For missing work, ask the handover custodian to check your scope."/>:
        <ul className="turnover-list">{result.items.map(w=><li key={w.id}><h2><Link to={archivePath(term,w.id)}>{w.title}</Link></h2><ArchiveFacts record={w}/><p>{w.summary}</p></li>)}</ul>}
      <nav className="auth-actions" aria-label="Archive pages">{page>1?<Link className="button button--secondary" to={archivePath(term)+'&page='+(page-1)}>Previous page</Link>:null}
        <p>Page {page}</p>{result.hasMore?<Link className="button button--secondary" to={archivePath(term)+'&page='+(page+1)}>Next page</Link>:null}</nav>
    </>:null}
  </div>
}
export function ArchiveFacts({record:w}:{record:ArchivedWork}){
  return <p>{w.reference?<><strong>{w.reference}</strong> · </>:null}{w.sourceTerm}{w.owner?' · '+w.owner:''}
    {w.dueAt?' · Due '+new Intl.DateTimeFormat('en-PH',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Manila'}).format(new Date(w.dueAt))+' (Manila)':w.dueOn?' · Due '+new Intl.DateTimeFormat('en-PH',{dateStyle:'medium',timeZone:'Asia/Manila'}).format(new Date(w.dueOn+'T00:00:00+08:00')):''}</p>
}
