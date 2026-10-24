import {useEffect,useState} from 'react'
import {Link,useParams,useRouteLoaderData} from 'react-router'
import {PageHeading,Panel} from '../../components/Page'
import {EmptyState,ErrorState,LoadingState} from '../../components/FeedbackState'
import type {WorkspaceContext} from '../auth/gateway'
import {dateLabel} from '../deliverables/DeliverableFacts'
import type {AgreementView,SynergiesApi} from './api'
import {SynergyForm} from './SynergyForm'

export function AgreementPage({api}:{api:SynergiesApi}){
 const {agreementId=''}=useParams(),context=useRouteLoaderData('workspace') as WorkspaceContext
 return <AgreementBody key={context.termId+('memberId'in context?context.memberId:context.guestAccessId)+agreementId} api={api} id={agreementId}/>
}
function AgreementBody({api,id}:{api:SynergiesApi;id:string}){
 const [item,setItem]=useState<AgreementView|null>(),[error,setError]=useState(false),[reload,setReload]=useState(0),[saved,setSaved]=useState(''),[savingEpoch,setSavingEpoch]=useState(0),[refreshing,setRefreshing]=useState(false),[pendingForm,setPendingForm]=useState(''),[responseSeen,setResponseSeen]=useState(false)
 useEffect(()=>{let live=true;void api.read(id).then(a=>{if(live){setItem(a);if(a?.interface.actions.length)setResponseSeen(true);setError(false);setRefreshing(false)}}).catch(()=>{if(live){setError(true);setRefreshing(false)}});return()=>{live=false}},[api,id,reload])
 const refresh=()=>{setRefreshing(true);setReload(n=>n+1)}
 const ui=item?.interface,active=item?.revisions.find(r=>r.revision===item.activeRevision)
 return <><Link className="button button--secondary" to="/working-together">Back to working together</Link>{saved?<p role="status">{saved}</p>:null}{error?<ErrorState title="Agreement unavailable" description="Check current access or connection." action={!item?<button className="button" disabled={!!pendingForm} onClick={refresh}>Refresh agreement</button>:undefined}/>:null}{item===undefined&&!error?<LoadingState title="Loading agreement"/>:item===undefined?null:!item?<EmptyState title="Agreement cannot be shown" description="The address is unavailable or your current scope changed. No restricted details are shown."/>:<>
 <PageHeading title={item.terms.output} description={`${ui?.requesterUnitName??'Requesting committee'} → ${ui?.receiverUnitName??'Receiving committee'}`}/>
 <p>Saved version {item.version} · {item.state} · Requesting owner: {item.requesterName}</p>
 <Panel title="Current negotiation"><p>{ui?.pendingWith?`Waiting on ${ui.pendingWith==='requester'?ui.requesterUnitName:ui.receiverUnitName} head`:'No pending response'}</p><p>Revision {item.revision} · Proposed deadline: {dateLabel(null,item.terms.dueOn)} · Effort: {item.terms.effort}</p><p className="record-text">{item.terms.criteria}</p><p>Named owner: {ui?.ownerName??'Receiving head must name an owner'}</p>{active?<p>Agreed deadline: {dateLabel(null,active.dueOn)} · Active revision {item.activeRevision}. {item.activeRevision!==item.revision?'Earlier accepted work remains active until replacement acceptance.':''}</p>:<p>No agreed deadline or active contribution yet.</p>}{item.contributionId?<p><Link className="button button--secondary" to={'/tasks/'+item.contributionId}>Open assigned work</Link></p>:null}{item.parentId?<p><Link to={'/deliverables/'+item.parentId}>Open independently permitted parent</Link></p>:<p>Parent content is not shared. This safe proposal grants no parent, sibling, finance or file access.</p>}{item.sources.length?<p>Independently readable finalized source manifests: {item.sources.map(id=>ui?.sourceOptions.find(s=>s.id===id)?.name??'Finalized file snapshot').join('; ')}</p>:<p>No independently readable source manifests in this view.</p>}</Panel>
 {responseSeen?<Panel title="Respond to proposal"><SynergyForm key={'response'+savingEpoch} api={api} agreement={item} blocked={!!pendingForm&&pendingForm!=='response'} onPendingChange={p=>setPendingForm(p?'response':'')} onRefresh={refresh} onSaved={r=>{setResponseSeen(false);setSaved(`Response recorded: ${r.state}, revision ${r.revision}.`);setSavingEpoch(n=>n+1);refresh()}}/></Panel>:null}
 {ui?.canAmend&&item.parentId?<details className="panel"><summary>Negotiate replacement terms</summary><SynergyForm key={'amend'+savingEpoch} api={api} parentId={item.parentId} agreement={item} amend blocked={!!pendingForm&&pendingForm!=='amend'} onPendingChange={p=>setPendingForm(p?'amend':'')} onRefresh={refresh} onSaved={r=>{setSaved(`Proposal recorded: revision ${r.revision}.`);setSavingEpoch(n=>n+1);refresh()}}/></details>:null}
 <button className="button button--secondary" disabled={refreshing||!!pendingForm} onClick={refresh}>Refresh agreement</button>
 <Panel title="Immutable history"><ol>{item.revisions.map(r=><li key={r.revision}><h3>Revision {r.revision} · {r.side}</h3><p className="record-text">{r.output}</p><p className="record-text">{r.criteria}</p><p>Proposed deadline: {dateLabel(null,r.dueOn)} · {r.effort} · Recorded {dateLabel(r.recordedAt,null)}</p><p className="record-text">Reason: {r.reason}</p></li>)}</ol><h3>Confirmations and decisions</h3><ul>{item.confirmations.map((c,i)=><li key={i}>Revision {c.revision} · {c.side} · {c.decision} · {dateLabel(c.recordedAt,null)}<p className="record-text">{c.reason}</p></li>)}</ul></Panel>
 </>}</>
}
