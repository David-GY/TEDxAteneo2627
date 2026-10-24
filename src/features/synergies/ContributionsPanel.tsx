import {useEffect,useState} from 'react'
import {useNavigate} from 'react-router'
import {Panel} from '../../components/Page'
import {LoadingState} from '../../components/FeedbackState'
import type {SynergiesApi,SynergyOptions} from './api'
import {CommitteeWork} from './WorkingTogetherPage'
import {SynergyForm} from './SynergyForm'
export function ContributionsPanel({api,termId,parentId,onPendingChange}:{api:SynergiesApi;termId:string;parentId:string;onPendingChange?:(pending:boolean)=>void}){
 const [options,setOptions]=useState<SynergyOptions|null>(),[error,setError]=useState(false),[reload,setReload]=useState(0),navigate=useNavigate()
 useEffect(()=>{let live=true;void api.options(termId,parentId).then(o=>{if(live){setOptions(o);setError(false)}}).catch(()=>{if(live){setError(true)}});return()=>{live=false}},[api,termId,parentId,reload])
 return <Panel title="Committee contributions"><p>Only independently permitted negotiations and contributions are shown. Task completion does not accept this deliverable.</p><CommitteeWork api={api} termId={termId} parentId={parentId} view="parent"/>{error?<p role="alert">Request options unavailable. <button className="button button--secondary" onClick={()=>setReload(n=>n+1)}>Refresh request options</button></p>:null}{options===undefined&&!error?<LoadingState title="Checking request-help access"/>:null}{options?<details className="synergy-request"><summary>Request help</summary><SynergyForm api={api} options={options} parentId={parentId} onPendingChange={onPendingChange} onRefresh={()=>setReload(n=>n+1)} onSaved={r=>void navigate('/working-together/'+r.agreementId)}/></details>:null}</Panel>
}
