import {ReadinessPanel} from './Readiness'
import type {ReadinessApi} from './readiness-api'
import {PublicityGate} from '../publicity/Publicity'
import type {PublicityApi} from '../publicity/api'
import {FinanceGate} from '../finance/FinanceDesk'
import type {FinanceApi} from '../finance/api'
import type {TimelineApi} from '../timeline/api'
import {ContributionsPanel} from '../synergies/ContributionsPanel'
import type {SynergiesApi} from '../synergies/api'
import {Files} from '../files/Files'
import type {FilesApi} from '../files/api'
import {Comments} from '../comments/Comments'
import type {CommentsApi} from '../comments/api'
import { useEffect, useState } from 'react'
import { Link, useLocation, useParams, useRouteLoaderData } from 'react-router'
import { isGuest, type WorkspaceContext } from '../auth/gateway'
import { PageHeading, Panel } from '../../components/Page'
import { EmptyState, ErrorState, LoadingState } from '../../components/FeedbackState'
import { filterSearch, parseFilters, type DeliverablesApi, type DeliverableDetail } from './api'
import { dateLabel, DeliverableFacts } from './DeliverableFacts'
import { DeliverableEditor } from './DeliverableEditor'
import type { DeliverableCommands } from './commands'
export function DeliverablePage({ api, commands, comments, files, synergies, timeline, finance, publicity, readiness }: { readiness?:ReadinessApi;publicity?:PublicityApi;finance?:FinanceApi; timeline?:TimelineApi;api: DeliverablesApi; commands?: DeliverableCommands; comments?:CommentsApi; files?:FilesApi; synergies?:SynergiesApi }) {
  const {deliverableId=''}=useParams(); const location=useLocation()
  const context=useRouteLoaderData('workspace') as WorkspaceContext|undefined
  const [negotiationPending,setNegotiationPending]=useState(false);const[schedulePending,setSchedulePending]=useState(false);const [reload,setReload]=useState(0);const key=deliverableId+':'+reload+':'+(context&&'memberId'in context?context.memberId:context&&'guestAccessId'in context?context.guestAccessId:'')
  const [state,setState]=useState<{key:string;data:DeliverableDetail|null;error:boolean}|null>(null)
  useEffect(()=>{let active=true;void api.read(deliverableId).then(data=>{if(active)setState({key,data,error:false})}).catch(()=>{if(active)setState({key,data:null,error:true})});return()=>{active=false}},[api,deliverableId,key])
  const from=location.state as {from?:unknown}|null
  const guest=!!context&&isGuest(context)
  const back=guest?'/shared':'/deliverables'+filterSearch(parseFilters(typeof from?.from==='string'?from.from:''))
  const loaded=state?.key===key;const item=loaded?state.data:null
  return <>
    <p><Link className="button button--secondary" to={back}>{guest?'Back to shared with me':'Back to deliverables'}</Link></p>
    {!loaded?<LoadingState title="Loading deliverable"/>:state.error?<ErrorState title="Deliverable unavailable" description="Access or connection could not be checked. Try reloading." action={<button className="button" onClick={()=>setReload(reload+1)}>Try again</button>}/>:!item?<><PageHeading title="Deliverable unavailable"/><EmptyState title="This deliverable cannot be shown" description="The address may be unavailable, or your access changed. No restricted details are shown." action={<Link className="button button--secondary" to={back}>Return to permitted work</Link>}/></>:<>
      <PageHeading title={item.title} description="Readiness checks current scope, contributions and formal reviews. Task completion alone is not final acceptance."/>
      <button className="button button--secondary" disabled={negotiationPending||schedulePending} onClick={()=>setReload(reload+1)}>Reload deliverable</button><p className="muted">Reloading the whole deliverable discards unsaved forms. Use the request form’s refresh to keep entered values.</p>
      {item.archivedAt?<p className="muted">This record is archived.</p>:null}
      <Panel title="Deliverable overview"><p>Phase: {item.phase??'Not set'}</p><p>{item.summary}</p><DeliverableFacts item={item}/><p className="muted">Original target: {dateLabel(item.originalDueAt,item.originalDueOn)}</p><p className="muted">Supporting committees show planning involvement. Agreed work appears in Committee contributions when independently permitted.</p></Panel>
      <Panel title="Outcome and acceptance criteria">{item.details?<><h3>Outcome</h3><p className="record-text">{item.details.outcome??'Not recorded'}</p><h3>Acceptance criteria</h3><p className="record-text">{item.details.acceptanceCriteria??'Not recorded'}</p><h3>Working notes</h3><p className="record-text">{item.details.body||'None recorded'}</p></>:<p>Summary access only. Participant details are not shared with your account.</p>}</Panel>
      {readiness?<ReadinessPanel key={key} api={readiness} files={files} id={deliverableId} onChanged={()=>setReload(n=>n+1)}/>:null}
      {commands&&context&&!guest?<div inert={negotiationPending}><DeliverableEditor timeline={timeline} onPendingChange={setSchedulePending} key={context.termId+context.memberId+deliverableId} api={commands} termId={context.termId} id={deliverableId} onSaved={()=>setReload(reload+1)} onReload={()=>setReload(reload+1)}/></div>:null}
      {synergies&&context&&!guest?<ContributionsPanel key={context.termId+context.memberId+deliverableId} api={synergies} termId={context.termId} parentId={deliverableId} onPendingChange={setNegotiationPending}/>:null}
      {publicity&&context?<PublicityGate api={publicity} term={context.termId} id={deliverableId}/>:null}{finance&&context?<FinanceGate api={finance} term={context.termId} id={deliverableId}/>:null}{files?<Files api={files} workId={deliverableId}/>:null}{comments?<Comments api={comments} workId={deliverableId}/>:null}
    </>}
  </>
}
