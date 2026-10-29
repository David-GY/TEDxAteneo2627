import {useEffect,useRef,useState,type ReactNode} from 'react'
import {recordAuthority,useRecordAuthority,type RecordAuthority} from './draftScope'
import {Link,useLocation,useRouteLoaderData} from 'react-router'
import type {AuthGateway,WorkspaceContext} from './gateway'
import {isGuest} from './gateway'

export function CurrentRecordScope({gateway,children}:{gateway:AuthGateway;children:ReactNode}){
 const {pathname}=useLocation(),workspace=useRouteLoaderData('workspace') as WorkspaceContext|undefined
 const parts=pathname.split('/').filter(Boolean),id=parts.at(-1)??''
 const requestScope=async(term:string,record:string)=>{const r=await gateway.requests!.read(term,record);return r?recordAuthority(r.state,['request'],[r.canEdit,r.canSubmit,r.canRevise,r.canCancel]):null}
 let read:(()=>Promise<RecordAuthority|null>)|undefined
 if(parts.length===2&&parts[0]==='tasks'&&gateway.tasks?.detail)read=async()=>{const r=await gateway.tasks!.detail!(id);return r?recordAuthority(r.state??'',['task',r.canManage],[r.canEdit]):null}
 if(parts.length===2&&parts[0]==='deliverables'&&gateway.deliverables&&workspace)read=async()=>{
  const r=await gateway.deliverables!.read(id);if(!r)return null
  const edit=!isGuest(workspace)&&gateway.deliverableCommands?await gateway.deliverableCommands.read(workspace.termId,id):null
  return recordAuthority(edit?.state??r.workflowState??'',['deliverable',r.details!==null,edit?.manager??false],[edit?.editable??false])
 }
 if(parts.length===3&&parts[0]==='requests'&&parts[1]!=='services'&&gateway.requests)read=()=>requestScope(parts[1],id)
 if(parts.length===3&&parts[0]==='finance'&&parts[1]!=='reviews'&&gateway.finance)read=async()=>{const r=await gateway.finance!.read(parts[1],id);return r?recordAuthority(r.request.state,['finance-case'],[r.request.canEdit,r.request.canSubmit,r.request.canRevise,r.request.canCancel]):null}
 if(parts.length===4&&parts[0]==='finance'&&parts[1]==='reviews'&&gateway.finAuthority)read=async()=>{const r=await gateway.finAuthority!.read(parts[2],id);return r?recordAuthority(r.state,['finance-review',r.isOwner],[r.canAssign,r.canDecide,r.canChangeAuthorization]):null}
 if(parts.length===3&&parts[0]==='publicity'&&gateway.publicity)read=async()=>{const r=await gateway.publicity!.read(parts[1],id);if(!r)return null;const request=gateway.requests?await gateway.requests.read(parts[1],id):null;return recordAuthority(r.state,['publicity',r.isOwner],[r.canAssign,r.canDecide,r.canRevoke,request?.canEdit??false,request?.canSubmit??false])}
 if(parts.length===3&&parts[0]==='reviews'&&gateway.inbox)read=async()=>{const r=await gateway.inbox!.read(parts[1],id);return r?recordAuthority(r.state,['review',r.package!==null],[r.canAssign,r.canNote,r.canTriage,r.canComplete,r.actions]):null}
 const task=parts[0]==='tasks',deliverable=parts[0]==='deliverables',guest=workspace&&isGuest(workspace)
 const denied=task||deliverable?<><Link className="button button--secondary" to={guest?'/shared':task?'/tasks':'/deliverables'}>{task?'Back to permitted tasks':guest?'Back to shared with me':'Back to deliverables'}</Link><h1>{task?'Task cannot be shown':'Deliverable unavailable'}</h1></>:<h1>Record unavailable</h1>
 return read?<RecordScope key={pathname} id={id} read={read} denied={denied}>{children}</RecordScope>:children
}

export function RecordScope({id,read,children,denied}:{id:string;read:()=>Promise<RecordAuthority|null>;children:ReactNode;denied?:ReactNode}){
 const latest=useRef(read);latest.current=read
 const {observe,epoch}=useRecordAuthority(id)
 const [state,setState]=useState<'checking'|'allowed'|'denied'|'error'>('checking')
 const [reload,setReload]=useState(0)
 useEffect(()=>{
  let live=true,sequence=0
  async function check(){
   const attempt=++sequence;setState('checking')
   try{const signature=await latest.current();if(live&&attempt===sequence){observe(signature);setState(signature===null?'denied':'allowed')}}
   catch{if(live&&attempt===sequence)setState('error')}
  }
  const refresh=()=>{if(document.visibilityState!=='hidden')void check()}
  void check();window.addEventListener('focus',refresh);const timer=setInterval(refresh,30000)
  return()=>{live=false;clearInterval(timer);window.removeEventListener('focus',refresh)}
 },[id,observe,reload])
 return <>{state==='checking'?<p role="status">Checking current record access. Your edits stay here while actions are paused.</p>:null}{state==='denied'?<>{denied}<p role="alert">This record is unavailable to your current account. Its private drafts have been cleared.</p></>:null}{state==='error'?<p role="alert">Record access could not be checked. Your inputs are kept; reconnect and check again.</p>:null}{state==='error'||state==='denied'?<button className="button button--secondary" onClick={()=>setReload(n=>n+1)}>Check record access again</button>:null}{state!=='denied'?<div key={epoch} inert={state!=='allowed'} hidden={state==='error'}>{children}</div>:null}</>
}
