import {useEffect,useState} from 'react'
import {Link,useParams,useRouteLoaderData} from 'react-router'
import {PageHeading} from '../../../components/Page'
import {ErrorState,LoadingState} from '../../../components/FeedbackState'
import type {WorkspaceContext} from '../../auth/gateway'
import {forgetRecordDrafts} from '../../auth/draftScope'
import {ConfigurationEditor} from './ConfigurationEditor'
import {ConfigurationReadError,type ConfigurationApi,type ConfigurationData} from './api'

export function ConfigurationPage({api}:{api:ConfigurationApi}){
 const c=useRouteLoaderData('workspace')as WorkspaceContext,{configurationType}=useParams(),identity='memberId'in c?c.memberId:c.guestAccessId
 return <ConfigurationHub key={c.termId+identity+(configurationType??'')} api={api} term={c.termId} identity={identity} type={configurationType}/>
}
export function ConfigurationHub({api,term,identity,type}:{api:ConfigurationApi;term:string;identity:string;type?:string}){
 const[epoch,setEpoch]=useState(0),[state,setState]=useState<{epoch:number;data:ConfigurationData|null;items:{id:string;label:string;governedKind:string}[];error:boolean}|null>(null)
 useEffect(()=>{let live=true;const read=async()=>{
  try{const[data,items]=type?[await api.read(type),[]]as const:[null,await api.list(term)]as const
   if(!live)return
   if(data&&data.termId!==term){forgetRecordDrafts(type!);throw new ConfigurationReadError(true)}
   setState({epoch,data,items:[...items],error:false})
  }catch(error){if(live){if(type&&error&&typeof error==='object'&&'denied'in error&&error.denied===true)forgetRecordDrafts(type);setState({epoch,data:null,items:[],error:true})}}
 };void read();return()=>{live=false}},[api,term,type,identity,epoch])
 useEffect(()=>{const check=()=>{if(document.visibilityState!=='hidden')setEpoch(n=>n+1)};window.addEventListener('focus',check);const timer=setInterval(check,30000);return()=>{window.removeEventListener('focus',check);clearInterval(timer)}},[])
 const current=state?.epoch===epoch?state:null
 return <><PageHeading title={current?.data?.typeLabel??'Service configuration'} description="Edit a private draft, validate it, review the impact, then publish explicitly. Existing cases keep their historical definitions."/>
 <p><Link to="/requests">Service catalog</Link>{type?<> · <Link to="/admin/config">Other permitted configurations</Link></>:null}</p><button className="button button--secondary" onClick={()=>setEpoch(n=>n+1)}>Refresh configuration (keep entered values)</button>
 {!current?<LoadingState/>:current.error?<ErrorState title="Configuration unavailable" description="Your current service configuration authority or connection could not be confirmed. Refresh to recheck; a connection failure keeps safe entered values."/>:current.data?<><p>Receiving service: {current.data.serviceLabel??'Not confirmed'}. {current.data.governedKind==='general'?'Ordinary service routing.':'Protected finance/publicity mapping — publication remains closed here.'}</p><ConfigurationEditor key={epoch} api={api} data={current.data} identity={identity} refreshed={()=>setEpoch(n=>n+1)}/></>:current.items.length?<ul>{current.items.map(item=><li key={item.id}><Link to={'/admin/config/'+item.id}>{item.label}</Link>{item.governedKind!=='general'?' · Protected routing':''}</li>)}</ul>:<p>No service is available within your current configuration scope. Ask the service head if a configuration change is needed.</p>}</>
}
