import {WorkReference} from '../work-references/WorkReference'
import { useEffect, useState, type FormEvent } from 'react'
import { Link, useLocation, useNavigate, useRouteLoaderData, useSearchParams } from 'react-router'
import { PageHeading, Panel } from '../../components/Page'
import { EmptyState, ErrorState, LoadingState } from '../../components/FeedbackState'
import type { WorkspaceContext } from '../auth/gateway'
import { filterSearch, parseFilters, type DeliverablesApi, type DeliverableList } from './api'
import { DeliverableFacts } from './DeliverableFacts'
import { DeliverableEditor } from './DeliverableEditor'
import type { DeliverableCommands } from './commands'
export function DeliverablesRoute({ api, commands }: { api: DeliverablesApi; commands?: DeliverableCommands }) {
  const context = useRouteLoaderData('workspace') as WorkspaceContext
  return <DeliverablesPage key={context.termId} api={api} commands={commands} termId={context.termId} />
}
export function DeliverablesPage({ api, commands, termId }: { api: DeliverablesApi; commands?: DeliverableCommands; termId: string }) {
  const navigate=useNavigate()
  const [params,setParams] = useSearchParams(); const location = useLocation()
  const search = filterSearch(parseFilters(params.toString())); const filters = parseFilters(search)
  const [reload,setReload] = useState(0)
  const key = termId + search + ':' + reload
  const [state,setState] = useState<{key:string;data:DeliverableList|null;error:boolean}|null>(null)
  useEffect(()=>{
    let active=true
    void api.list(termId,parseFilters(search)).then(data=>{if(active)setState({key,data,error:false})}).catch(()=>{if(active)setState({key,data:null,error:true})})
    return()=>{active=false}
  },[api,termId,search,key])
  const loaded=state?.key===key; const data=loaded?state.data:null
  function apply(event:FormEvent<HTMLFormElement>){event.preventDefault();const fields=new FormData(event.currentTarget);const p=new URLSearchParams();for(const [k,v] of fields)if(typeof v==='string'&&v)p.set(k,v);setParams(filterSearch(parseFilters(p.toString())))}
  const move=(page:number)=>setParams(filterSearch({...filters,page}))
  return <>
    <PageHeading title="Core deliverables" description="Find shared event outputs, accountable owners and the next action." />
    <p className="muted">Readiness follows current scope, required reviews and independent acceptance; task completion is separate. Dates use Manila time; date-only deadlines end at 23:59.</p>
    <div className="auth-actions"><Link className="button button--secondary" to="/working-together/timeline">Committee timeline</Link><button className="button button--secondary" onClick={()=>setReload(reload+1)}>Reload deliverables</button><Link className="button button--secondary" to="/people">Find a process contact</Link></div>
    {commands?<DeliverableEditor api={commands} termId={termId} onSaved={id=>void navigate('/deliverables/'+id)}/>:null}
    {!loaded ? <LoadingState title="Loading deliverables" /> : state.error ? <ErrorState title="Deliverables unavailable" description="Check access or connection, then reload. No cached records are shown." action={<button className="button" onClick={()=>setReload(reload+1)}>Try again</button>} /> : data ? <>
      <Panel title="Filter deliverables">
        <form key={search} onSubmit={apply} className="deliverable-filters">
          <label>Phase<select name="phase" defaultValue={filters.phase}><option value="">All phases</option>{filters.phase&&!data.options.phases.includes(filters.phase)?<option value={filters.phase}>Unavailable phase filter</option>:null}{data.options.phases.map(p=><option key={p}>{p}</option>)}</select></label>
          <label>Committee<select name="unit" defaultValue={filters.unit}><option value="">All committees</option>{filters.unit&&!data.options.units.some(u=>u.id===filters.unit)?<option value={filters.unit}>Unavailable committee filter</option>:null}{data.options.units.map(u=><option key={u.id} value={u.id}>{u.name}</option>)}</select></label>
          <label>Owner<select name="owner" defaultValue={filters.owner}><option value="">All owners</option>{filters.owner&&!data.options.owners.some(o=>o.id===filters.owner)?<option value={filters.owner}>Unavailable owner filter</option>:null}{data.options.owners.map(o=><option key={o.id} value={o.id}>{o.name}</option>)}</select></label>
          <div className="deliverable-toggles">{[{name:'blocked',label:'Blocked',checked:filters.blocked},{name:'overdue',label:'Overdue',checked:filters.overdue},{name:'mine',label:'Involves my committee',checked:filters.mine},{name:'review',label:'Gate review pending',checked:filters.review}].map(f=><label key={f.name}><input type="checkbox" name={f.name} value="1" defaultChecked={f.checked}/>{f.label}</label>)}</div>
          <div className="auth-actions"><button className="button" type="submit">Apply filters</button><button className="button button--secondary" type="button" onClick={()=>setParams('')}>Clear filters</button></div>
        </form>
      </Panel>
      <p role="status">{data.total} permitted {data.total===1?'deliverable':'deliverables'} · Page {data.page}</p>
      {data.items.length ? <div className="deliverable-list">{data.items.map(item=><article className="panel deliverable-row" key={item.id}>
        <h2><Link to={`/deliverables/${item.id}`} state={{from:location.search}}>{item.title}</Link></h2>
        <WorkReference compact reference={item.reference} id={item.id} kind="deliverable"/>
        <p className="muted">Phase: {item.phase ?? 'Not set'}</p><p>{item.summary}</p><DeliverableFacts item={item}/>
      </article>)}</div> : <EmptyState title={data.total?'No deliverables on this page':'No deliverables match'} description={data.total?'Records may have changed. Return to the first page.':'Clear filters or check with a process contact. Only permitted deliverables are counted.'} action={<button className="button button--secondary" onClick={()=>data.total?move(1):setParams('')}>{data.total?'Go to first page':'Clear filters'}</button>} />}
      <nav className="deliverable-pagination auth-actions" aria-label="Deliverable pages"><button className="button button--secondary" disabled={data.page<=1} onClick={()=>move(data.page-1)}>Previous page</button><button className="button button--secondary" disabled={data.page*data.pageSize>=data.total} onClick={()=>move(data.page+1)}>Next page</button></nav>
    </> : null}
  </>
}
