import {useEffect,useState} from 'react'
import {Link} from 'react-router'
import {Panel} from '../../components/Page'
import {ErrorState,LoadingState} from '../../components/FeedbackState'
import {dateLabel} from '../deliverables/DeliverableFacts'
import type {ContributionView,SynergiesApi} from './api'
export function ContributionTerms({api,id}:{api:SynergiesApi;id:string}){
 const [item,setItem]=useState<ContributionView|null>(),[error,setError]=useState(false),[reload,setReload]=useState(0)
 useEffect(()=>{let live=true;void api.contribution(id).then(c=>{if(live){setItem(c);setError(false)}}).catch(()=>{if(live){setError(true);setItem(undefined)}});return()=>{live=false}},[api,id,reload])
 return <Panel title="Agreed contribution terms"><button className="button button--secondary" onClick={()=>setReload(n=>n+1)}>Refresh contribution terms</button>{error?<ErrorState title="Contribution unavailable" description="Refresh to check current access and connection."/>:item===undefined?<LoadingState title="Loading agreed terms"/>:item?<><p>Accepted revision {item.revision} · Owner: {item.ownerName} · Effort: {item.effort}</p><p>Agreed deadline: {dateLabel(null,item.dueOn)}</p><p className="record-text">{item.output}</p><h3>Acceptance criteria</h3><p className="record-text">{item.criteria}</p>{item.parentId?<Link to={'/deliverables/'+item.parentId}>Open independently permitted parent</Link>:<p>Parent content is not shared with this task.</p>}<p>Pending negotiations do not replace these active terms. Task completion grants no deliverable or FIN/MCD acceptance.</p></>:<p>Agreed terms are no longer available in this scope.</p>}</Panel>
}
