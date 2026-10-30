import {useEffect,useRef,useState} from 'react'
import {Link,useRouteLoaderData} from 'react-router'
import {PageHeading} from '../../../components/Page'
import {isGuest,type WorkspaceContext} from '../../auth/gateway'
import {forgetRecordDrafts} from '../../auth/draftScope'
import {LayoutEditor} from './LayoutEditor'
import type {LayoutAdminApi,LayoutConfiguration,LayoutTarget} from './api'
import '../../overview/overview.css'
export function LayoutsPage({api}:{api:LayoutAdminApi}){const c=useRouteLoaderData('workspace')as WorkspaceContext;return isGuest(c)?<p>Layout publishing is unavailable for guests. <Link to="/shared">Open shared work</Link></p>:<LayoutsHub key={c.termId+c.termMembershipId} api={api} term={c.termId} identity={c.termMembershipId}/>}
function LayoutsHub({api,term,identity}:{api:LayoutAdminApi;term:string;identity:string}){
 const[targets,setTargets]=useState<LayoutTarget[]|null>(null),[selected,setSelected]=useState(''),[data,setData]=useState<LayoutConfiguration|null>(null),[error,setError]=useState(false),[epoch,setEpoch]=useState(0),[locked,setLocked]=useState(false),[older,setOlder]=useState(false),generation=useRef(0)
 const target=targets?.find(t=>t.kind+':'+t.id===selected)
 useEffect(()=>{let live=true;generation.current++;setData(null);setError(false);void api.targets(term).then(async list=>{if(!live)return;setTargets(list);const current=list.find(t=>t.kind+':'+t.id===selected);if(current){const value=await api.read(term,current);if(live)setData(value)}else if(selected){forgetRecordDrafts('layout-'+term);setLocked(false);setSelected('')}}).catch(e=>{if(live){if(e?.denied){forgetRecordDrafts('layout-'+term);setLocked(false)}setData(null);setTargets(null);setError(true)}});return()=>{live=false;generation.current++}},[api,term,selected,epoch])
 useEffect(()=>{const check=()=>{if(document.visibilityState!=='hidden')setEpoch(n=>n+1)};window.addEventListener('focus',check);return()=>window.removeEventListener('focus',check)},[])
 async function history(){if(!target||!data?.nextBefore)return;const requested=generation.current;setOlder(true);try{const next=await api.read(term,target,data.nextBefore);if(requested===generation.current)setData({...data,history:[...data.history,...next.history],nextBefore:next.nextBefore})}catch(e){if(requested===generation.current){if((e as {denied?:boolean})?.denied)forgetRecordDrafts('layout-'+term);setError(true)}}finally{setOlder(false)}}
 return <><PageHeading title="Dashboard layouts" description="Publish a bounded default for a role or committee. Members keep their own arrangements; work access is checked independently."/><p><Link to="/admin">Organization administration</Link> · <Link to="/">My overview</Link></p>
 <p>Defaults use one matching committee layout, then one matching role layout, then the term default. Overlapping layouts at the same level fall back to a broader default. This page never changes roles or data access.</p>
 <button className="button button--secondary" onClick={()=>setEpoch(n=>n+1)}>Refresh layout settings (keep inputs)</button>
 {error?<p role="alert">Layout settings unavailable. Recheck connection and current authority. A connection failure keeps safe inputs; confirmed permission loss clears private client drafts.</p>:targets===null?<p>Checking current layout authority…</p>:!targets.length?<p>No layout target is available in your current publishing scope.</p>:<><label>Layout audience<select className="overview-example" disabled={locked} value={selected} onChange={e=>setSelected(e.target.value)}><option value="">Choose a role, committee or term default</option>{targets.map(t=><option key={t.kind+':'+t.id} value={t.kind+':'+t.id}>{t.kind==='unit'?'Committee':t.kind==='role'?'Role':'Workspace'} · {t.label}</option>)}</select></label>{target&&data?<LayoutEditor key={selected+':'+epoch} api={api} term={term} identity={identity} target={target} data={data} refreshed={()=>setEpoch(n=>n+1)} onLock={setLocked}/>:target?<p>Checking current publication and private draft…</p>:null}{data?.nextBefore?<button className="button button--secondary" disabled={older||locked} onClick={()=>void history()}>Load older layout history</button>:null}</>}
 </>
}
