import {useState} from 'react'
import {OverviewLane,SecondaryViews,WorkHelp} from './OverviewViews'
import {resolveLayout,type Layout} from './layout'
import type {OverviewRow} from './api'

const example:OverviewRow={id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',source:'task',title:'Prepare the fictional handoff',owner:'Fictional River',dueOn:'2027-04-10',dueAt:null,lane:'actionable',action:'Attach the agreed final evidence',person:'Fictional River',state:'in_progress',committee:'Fictional Programme',overdue:false}
const cases={
 newcomer:{label:'Late joiner — no assigned work',items:[]},
 assignee:{label:'Current assignee',items:[example]},
 head:{label:'Committee head — missing reviewer',items:[{...example,id:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8',source:'review' as const,termId:'cccccccc-cccc-4ccc-8ccc-ccccccccccc8',requestedOn:'2027-04-10',dueOn:null,title:'Review the fictional service request',owner:'Fictional Alex',action:'Assign an independent reviewer',person:'Fictional Alex',state:'paused_missing_reviewer'}]},
 guest:{label:'Guest — explicitly shared task only',items:[{...example,title:'Check the fictional shared handoff',committee:null}]},
}
export function LayoutPreview({layout}:{layout:Layout}){
 const[scenario,setScenario]=useState<keyof typeof cases>('newcomer'),[open,setOpen]=useState(false),guest=scenario==='guest',resolved=resolveLayout(layout,guest?'guest':'member')
 return <details className="work-section" onToggle={e=>setOpen(e.currentTarget.open)}><summary>Try fictional layouts</summary>{open?<section aria-label="Fictional layout preview">
 <p>Fictional examples only. No account is impersonated, no work is changed and no additional data is queried. Example work links are illustrative and cannot open a real work item.</p>
 <label>Example person<select className="overview-example" value={scenario} onChange={e=>setScenario(e.target.value as keyof typeof cases)}>{Object.entries(cases).map(([id,value])=><option key={id} value={id}>{value.label}</option>)}</select></label>
 {resolved.repaired?<p>Some selected views are unavailable for this audience; showing the safe guest default.</p>:null}
 <div className="overview-fictional"><OverviewLane items={cases[scenario].items} lane="actionable" illustrative/><WorkHelp guest={guest}/><SecondaryViews layout={resolved.layout} items={cases[scenario].items} illustrative/></div>
 </section>:null}</details>
}
