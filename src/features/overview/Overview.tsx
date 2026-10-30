import {useCallback,useEffect,useState} from 'react'
import {Link,useRouteLoaderData} from 'react-router'
import {PageHeading} from '../../components/Page'
import {LoadingState,ErrorState} from '../../components/FeedbackState'
import {isGuest,type WorkspaceContext} from '../auth/gateway'
import {dateLabel} from '../deliverables/DeliverableFacts'
import type {OverviewApi,OverviewResult} from './api'
import {defaultLayout,resolveLayout,validateLayout,viewStorageKey,type Layout} from './layout'
import {LayoutControls} from './LayoutControls'
import {LayoutPreview} from './LayoutPreview'
import {AccountLayouts} from './AccountLayouts'
import {OverviewLane,SecondaryViews,WorkHelp} from './OverviewViews'
import './overview.css'

export function Overview({api}:{api:OverviewApi}){
 const context=useRouteLoaderData('workspace')as WorkspaceContext,subject=isGuest(context)?'guest:'+context.guestAccessId:'member:'+context.termMembershipId
 return <OverviewBody key={context.organizationId+context.termId+subject} api={api} context={context} subject={subject}/>
}
function OverviewBody({api,context,subject}:{api:OverviewApi;context:WorkspaceContext;subject:string}){
 const termId=context.termId,guest=isGuest(context),audience=guest?'guest':'member',storageKey=viewStorageKey(context.organizationId,termId,subject)
 const[result,setResult]=useState<OverviewResult|null>(null),[error,setError]=useState(false),[reload,setReload]=useState(0)
 const[viewLocked,setViewLocked]=useState(false)
 const[view,setView]=useState(()=>{try{
  const raw=localStorage.getItem(storageKey)
  if(raw&&raw.length>10000)throw Error('Saved view too large')
  const resolved=resolveLayout(raw===null?null:JSON.parse(raw),audience)
  return{...resolved,personal:raw!==null,message:resolved.repaired?'Saved view is no longer supported. Default view restored; use Restore default view to repair the saved setting.':raw?'Your view is saved on this device.':'Using the default view. No setup needed.'}
 }catch{return{...resolveLayout(null,audience),personal:true,repaired:true,message:'Saved view could not be loaded. Default view is available; use Restore default view to repair the saved setting.'}}})
 const publishedDefault=useCallback((layout:Layout|null,source:string)=>{setView(previous=>previous.personal?previous:{layout:layout??defaultLayout(audience),personal:false,repaired:false,message:layout?`Using the published ${source} layout. No setup needed.`:'Using the default view. No setup needed.'})},[audience])
 function usePublished(layout:Layout|null,source:string){let message=layout?`Using the published ${source} layout. No setup needed.`:'Using the default view. No setup needed.';try{localStorage.removeItem(storageKey)}catch{message+=' Device preference could not be cleared; it may return after reload.'}setView({layout:layout??defaultLayout(audience),personal:false,repaired:false,message})}
 function changeLayout(layout:Layout){
  if(!validateLayout(layout,audience))return
  let message='Your view is saved on this device.'
  try{localStorage.setItem(storageKey,JSON.stringify(layout))}catch{message='Your current view could not be saved on this device. It remains available until you leave this page.'}
  setView({layout,personal:true,repaired:false,message})
 }
 useEffect(()=>{let live=true;void api.read(termId).then(r=>{if(live){setResult(r);setError(false)}}).catch(()=>{if(live){setResult(null);setError(true)}});return()=>{live=false}},[api,termId,reload])
 useEffect(()=>{const refresh=()=>{setResult(null);setReload(n=>n+1)},visible=()=>{if(document.visibilityState==='visible')refresh()};window.addEventListener('focus',refresh);document.addEventListener('visibilitychange',visible);return()=>{window.removeEventListener('focus',refresh);document.removeEventListener('visibilitychange',visible)}},[])
 return <><PageHeading title="Overview" description="Your next actions and work waiting on someone else."/><p>Open a work title below to act. Task completion and independent approval stay separate.</p>
 <button className="button button--secondary" onClick={()=>{setResult(null);setReload(n=>n+1)}}>Refresh overview</button>
 {error?<ErrorState title="Overview unavailable" description="Check access or connection, then refresh the overview."/>:!result?<LoadingState title="Loading next actions"/>:<>
 <p>Refreshed {dateLabel(result.refreshedAt,null)}. Dates and overdue cutoff use Manila time.{result.hasMore?' Showing the first 50 permitted records; open Department inbox, My tasks or Core deliverables for more.':''}</p>
 <OverviewLane items={result.items} lane="actionable"/>
 </>}
 <WorkHelp guest={guest}/>
 {!guest&&context.capabilities?.some(c=>['admin.configure','committee.manage'].includes(c))?<p><Link to="/admin/layouts">Publish a role or committee layout</Link></p>:null}
 {view.repaired?<p role="alert">{view.message}</p>:null}
 <LayoutControls disabled={viewLocked} layout={view.layout} audience={audience} message={view.repaired?'Use Restore default view to replace the unsupported saved setting.':view.message} onChange={changeLayout} onReset={()=>changeLayout(defaultLayout(audience))}/>
 {!guest&&api.layouts?<AccountLayouts refresh={reload} api={api.layouts} term={termId} identity={subject} layout={view.layout} onUse={changeLayout} onDefault={publishedDefault} onPublished={usePublished} onLock={setViewLocked}/>:null}
 {result&&!error?<SecondaryViews layout={view.layout} items={result.items}/>:null}
 <LayoutPreview layout={view.layout}/></>
}
