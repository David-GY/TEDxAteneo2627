import {useEffect,useState} from 'react'
import './timeline.css'
import {Link,useRouteLoaderData,useSearchParams} from 'react-router'
import {PageHeading,Panel} from '../../components/Page'
import {EmptyState,ErrorState,LoadingState} from '../../components/FeedbackState'
import {isGuest,type WorkspaceContext} from '../auth/gateway'
import {addDays,eventDay,manilaDay,schedule,windowFor} from './dates'
import {parseTimelineQuery,timelineSearch,type TimelineQuery} from './filters'
import type {TimelineApi,TimelineItem,TimelineResult} from './api'
const offset=(a:string,b:string)=>(Date.parse(a+'T00:00:00Z')-Date.parse(b+'T00:00:00Z'))/86400000
function dates(item:TimelineItem){const s=schedule(item.plannedStartOn,item.dueOn,item.dueAt);return s.kind==='range'?`${s.start} to ${s.end} (inclusive)`:s.kind==='deadline'?`Deadline ${s.end}; start not set`:s.start?`Starts ${s.start}; end missing`:'Start and end missing'}
function Chronology({items,allItems,edges}:{items:TimelineItem[];allItems:TimelineItem[];edges:TimelineResult['dependencies']}){
 return <ul className="timeline-list">{items.map(i=><li key={i.id}>
 <h3><Link to={i.href}>{i.title}</Link></h3><p>{i.type} · {i.status==='todo'?'To do':i.status.replaceAll('_',' ')}{i.blocked?' · Blocked':''}{i.overdue?' · Overdue':''}</p>
 <p>{dates(i)} · Owner: {i.owner.name}</p><p>Primary committee: {i.primaryUnit?.name??'Not assigned'}{i.phase?' · Phase: '+i.phase:''}</p>
 {i.participatingUnits.length?<p>Participating: {i.participatingUnits.map(u=>u.name).join(', ')}</p>:null}
 <p>Original target: {i.originalDueOn??(i.originalDueAt?manilaDay(i.originalDueAt):'Not set')} · Version {i.version}</p>
 {edges.filter(e=>e.successorId===i.id).map(e=>{const p=allItems.find(x=>x.id===e.predecessorId)!;return <p key={e.id}>{e.required?'Required finish-to-start':e.type==='informational'?'Informational':'Optional finish-to-start'}: <Link to={p.href}>{p.title}</Link></p>})}
 </li>)}</ul>
}
function Chart({items,edges,start,end,today}:{items:TimelineItem[];edges:TimelineResult['dependencies'];start:string;end:string;today:string}){
 const days=offset(end,start)+1,width=days*36,rows=items.filter(i=>i.endOn!==null&&i.endOn>=start&&(i.plannedStartOn??i.endOn)<=end).sort((a,b)=>(a.primaryUnit?.name??'').localeCompare(b.primaryUnit?.name??'')||a.id.localeCompare(b.id))
 const x=(day:string)=>Math.max(0,Math.min(days,offset(day,start)))*36
 const row=(i:TimelineItem)=>rows.findIndex(r=>r.id===i.id)
 return <section aria-label="Read-only calendar chart"><p>Each row names its primary committee. Bars include both days; diamonds mark deadlines with no start. Lines connect only loaded records drawn here. Use the chronological list for complete dates and text link descriptions.</p>
 <div className="timeline-scroll" role="region" aria-label="Calendar chart, scroll horizontally" tabIndex={0}>
 <div className="timeline-canvas" style={{width:width+260}}><div className="timeline-axis" style={{gridTemplateColumns:`260px repeat(${days},36px)`}}><strong>Committee / work</strong>{Array.from({length:days},(_,n)=><span key={n}>{addDays(start,n).slice(8)}</span>)}</div>
 <div className="timeline-chart-body" style={{height:rows.length*88}}>
 {rows.map((i,n)=>{const s=schedule(i.plannedStartOn,i.dueOn,i.dueAt);if(s.kind==='unscheduled')return null;const left=x(s.kind==='range'?s.start:s.end),right=Math.min(width,x(s.end)+36),deadline=s.kind==='deadline'
 return <div className="timeline-chart-row" key={i.id} style={{top:n*88}}><div className="timeline-row-name"><span>{i.primaryUnit?.name??'No committee'}</span><Link to={i.href}>{i.title}</Link></div><div className="timeline-track" style={{width}}><Link className={'timeline-bar'+(deadline?' timeline-deadline':'')} to={i.href} aria-label={i.title+', '+dates(i)} style={{left,width:deadline?36:Math.max(36,right-left)}}>{deadline?'◆':'Open'}</Link></div></div>})}
 <svg className="timeline-edges" width={width} height={rows.length*88} aria-hidden="true">{edges.filter(e=>rows.some(i=>i.id===e.predecessorId)&&rows.some(i=>i.id===e.successorId)).map(e=>{const p=rows.find(i=>i.id===e.predecessorId)!,s=rows.find(i=>i.id===e.successorId)!,a=x(p.endOn!)+18,b=x(s.plannedStartOn??s.endOn!)+18,y1=row(p)*88+52,y2=row(s)*88+52;return <path key={e.id} d={`M ${a} ${y1} H ${Math.min(width-2,Math.max(a,b)+12)} V ${y2} H ${b}`} fill="none" className={e.required?'timeline-edge-required':'timeline-edge-info'}/>})}</svg>
 {[{day:today,label:'Today'},{day:eventDay,label:'Event'}].filter(m=>m.day>=start&&m.day<=end).map(m=><div aria-hidden="true" key={m.label} className="timeline-marker" style={{left:260+x(m.day)+18,height:Math.max(44,rows.length*88)}}><span>{m.label}</span></div>)}
 </div></div></div>
 {rows.length===0?<p>No dated rows intersect this window on the current page.</p>:null}<p>Solid line: required finish-to-start. Dashed line: informational or optional. Chart links open records; there are no schedule gestures.</p></section>
}
function TimelineBody({api,termId}:{api:TimelineApi;termId:string}){
 const[params,setParams]=useSearchParams(),today=manilaDay(new Date().toISOString()),q=parseTimelineQuery(params.toString(),today),query=timelineSearch(q),window=windowFor(q.anchor,q.scale)
 const[epoch,setEpoch]=useState(0),[state,setState]=useState<{key:string;result:TimelineResult|null;error:boolean}|null>(null),key=query+':'+epoch
 const refresh=()=>setEpoch(n=>n+1)
 useEffect(()=>{let live=true;const f={units:q.units,...(!q.overdue?{from:window.start}:{}),to:q.overdue?today:window.end,includeUnscheduled:q.includeUnscheduled,blocked:q.blocked,overdue:q.overdue,...(q.owner?{owner:q.owner}:{}),...(q.phase?{phase:q.phase}:{}),...(q.type?{type:q.type}:{})};void api.read(termId,f,q.page).then(result=>{if(live)setState({key,result,error:false})}).catch(()=>{if(live)setState({key,result:null,error:true})});return()=>{live=false}
 // The canonical URL is the dependency for every validated filter and calendar field.
 },[api,termId,key])
 useEffect(()=>{const visible=()=>{if(document.visibilityState==='visible')refresh()};globalThis.window.addEventListener('focus',refresh);document.addEventListener('visibilitychange',visible);const timer=setInterval(visible,30000);return()=>{globalThis.window.removeEventListener('focus',refresh);document.removeEventListener('visibilitychange',visible);clearInterval(timer)}},[])
 const current=state?.key===key?state:null,result=current?.result,options=result?.options
 function change(patch:Partial<TimelineQuery>,paging=false){setParams(timelineSearch({...q,...patch,...(paging?{}:{page:1})}).slice(1))}
 function shift(direction:number){try{change({anchor:direction<0?addDays(window.start,-(q.scale==='week'?7:1)):addDays(window.end,1)})}catch{/* The supported calendar boundary disables navigation. */}}
 let previous=true,next=true;try{addDays(window.start,-1)}catch{previous=false}try{addDays(window.end,1)}catch{next=false}
 const dated=result?.items.filter(i=>i.endOn!==null)??[],unscheduled=result?.items.filter(i=>i.endOn===null)??[]
 return <><PageHeading title="Committee timeline" description="Permitted commitments, owners and dependencies across Manila calendar days."/>
 <p><Link to="/working-together">Working together</Link> · <Link to="/deliverables">Core deliverables</Link></p>
 <p>Today: {today} · Event: {eventDay}. Only loaded permitted rows and links are shown; this is a partial graph. Overlaps do not establish capacity or approval.</p>
 <div className="auth-actions"><button className="button button--secondary" disabled={!previous} onClick={()=>shift(-1)}>Previous {q.scale}</button><button className="button button--secondary" onClick={()=>change({anchor:today})}>Today</button><button className="button button--secondary" disabled={!next} onClick={()=>shift(1)}>Next {q.scale}</button><button className="button button--secondary" onClick={refresh}>Refresh timeline</button></div>
 <div className="timeline-controls"><label>Calendar date<input type="date" min="0001-01-01" max="9999-12-31" value={q.anchor} onChange={e=>{if(e.target.value)change({anchor:parseTimelineQuery('?date='+e.target.value,today).anchor})}}/></label><label>Scale<select aria-label="Scale" value={q.scale} onChange={e=>change({scale:e.target.value as TimelineQuery['scale']})}><option value="week">Week</option><option value="month">Month</option></select></label><label>View<select aria-label="View" value={q.view} onChange={e=>change({view:e.target.value as TimelineQuery['view']},true)}><option value="chart">Chart and chronological list</option><option value="list">Chronological list</option></select></label></div>
 <details className="timeline-filter-panel"><summary>Filter permitted work</summary><div className="timeline-controls">
 <label>Committees · multiple selection<select aria-label="Committees · multiple selection" multiple size={3} value={q.units} onChange={e=>change({units:Array.from(e.target.selectedOptions,o=>o.value)})}>{q.units.filter(id=>!options?.units.some(u=>u.id===id)).map(id=><option key={id} value={id}>Selected committee (access checked)</option>)}{options?.units.map(u=><option key={u.id} value={u.id}>{u.name}</option>)}</select></label>
 <label>Owner<select aria-label="Owner" value={q.owner} onChange={e=>change({owner:e.target.value})}><option value="">All permitted owners</option>{q.owner&&!options?.owners.some(o=>o.id===q.owner)?<option value={q.owner}>Selected owner (access checked)</option>:null}{options?.owners.map(o=><option key={o.id} value={o.id}>{o.name}</option>)}</select></label>
 <label>Phase<select aria-label="Phase" value={q.phase} onChange={e=>change({phase:e.target.value})}><option value="">All phases</option>{q.phase&&!options?.phases.includes(q.phase)?<option value={q.phase}>Selected phase (access checked)</option>:null}{options?.phases.map(p=><option key={p} value={p}>{p}</option>)}</select></label>
 <label>Work type<select aria-label="Work type" value={q.type} onChange={e=>change({type:e.target.value as TimelineQuery['type']})}><option value="">All work</option><option value="deliverable">Deliverables</option><option value="contribution">Contributions</option><option value="task">Tasks</option></select></label>
 </div><div className="timeline-checks">{(['blocked','overdue','includeUnscheduled']as const).map(k=><label key={k}><input type="checkbox" checked={q[k]} onChange={e=>change({[k]:e.target.checked})}/>{k==='blocked'?'Blocked only':k==='overdue'?'Overdue only, including earlier windows':'Include unscheduled work outside this window'}</label>)}</div><button className="button button--secondary" onClick={()=>change({units:[],owner:'',phase:'',type:'',blocked:false,overdue:false,includeUnscheduled:true})}>Clear work filters</button></details>
 <h2>{q.scale==='week'?'Week':'Month'}: {window.start} to {window.end}</h2>
 {!current?<LoadingState title="Checking current timeline access"/>:current.error?<ErrorState title="Timeline could not load" description="Current records and filter choices are hidden until access and connection can be checked." action={<button className="button" onClick={refresh}>Retry timeline</button>}/>:!result?<EmptyState title="Timeline access changed" description="This core committee view is unavailable to your current account. Previously loaded records and choices have been removed." action={<button className="button" onClick={refresh}>Check timeline access</button>}/>:<>
 <p role="status">{result.items.length} loaded of {result.total} permitted matching records · Page {result.page}. Dates use Asia/Manila.</p>
 {result.items.length===0?<EmptyState title="No permitted work matches" description="Try another date or clear the work filters. Unscheduled work can be included independently of the calendar window."/>:<>
 {q.view==='chart'?<Panel title="Calendar commitments"><Chart items={result.items} edges={result.dependencies} start={window.start} end={window.end} today={today}/></Panel>:null}
 <Panel title="Chronological work"><p>Open a record to use its authorized editing forms. Original targets and approval rules remain separate.</p>{dated.length?<Chronology items={dated} allItems={result.items} edges={result.dependencies}/>:<p>No dated work on this page.</p>}</Panel>
 <Panel title="Unscheduled work"><p>Incomplete dates stay here without an invented duration or finish. Counts describe this loaded page.</p>{unscheduled.length?<Chronology items={unscheduled} allItems={result.items} edges={result.dependencies}/>:<p>No unscheduled work on this page.</p>}</Panel>
 </>}
 <nav className="auth-actions" aria-label="Timeline pages"><button className="button button--secondary" disabled={q.page<=1} onClick={()=>change({page:q.page-1},true)}>Previous page</button><button className="button button--secondary" disabled={q.page*result.pageSize>=result.total||q.page>=10000} onClick={()=>change({page:q.page+1},true)}>Next page</button></nav>
 </>}
 </>
}
export function TimelinePage({api}:{api:TimelineApi}){const context=useRouteLoaderData('workspace') as WorkspaceContext;if(isGuest(context))return <EmptyState title="Core committee view" description="Use your exact shared record links."/>;return <TimelineBody key={context.termId+context.memberId} api={api} termId={context.termId}/>}
