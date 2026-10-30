import {useEffect,useState} from 'react'
import {Panel} from '../../../components/Page'
import {useFinDecision} from '../../finance/DecisionMemory'
import {LayoutControls} from '../../overview/LayoutControls'
import {LayoutPreview} from '../../overview/LayoutPreview'
import {defaultLayout,type Layout} from '../../overview/layout'
import {widgetCatalog} from '../../../app/widgetCatalog'
import type {LayoutAdminApi,LayoutCommand,LayoutConfiguration,LayoutTarget,LayoutReview} from './api'
function Description({layout}:{layout:Layout|null}){return layout?<ol>{layout.widgets.map(w=><li key={w.id}>{widgetCatalog.find(c=>c.id===w.id)?.label} · {w.size==='wide'?'Full width':'Compact on wide screens'}</li>)}{!layout.widgets.length?<li>No secondary widgets. Next actions and help stay visible.</li>:null}</ol>:<p>Built-in default; no published layout.</p>}
export function LayoutEditor({api,term,identity,target,data,refreshed,onLock}:{api:LayoutAdminApi;term:string;identity:string;target:LayoutTarget;data:LayoutConfiguration;refreshed:()=>void;onLock:(locked:boolean)=>void}){
 const draft=data.drafts[0],initial=JSON.stringify(draft?.definition??data.definition??defaultLayout('member'))
 const mem=useFinDecision<LayoutCommand,{version:number}>(api,'layout:layout-'+term+':'+target.kind+':'+target.id+':'+identity,{layout:initial,baseline:initial,reason:'',rollback:draft?.rollbackVersionId??'',baselineRollback:draft?.rollbackVersionId??''})
 const layout=JSON.parse(mem.fields.layout)as Layout,[review,setReview]=useState<LayoutReview|null>(null),[ack,setAck]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(''),dirty=mem.fields.layout!==mem.fields.baseline||mem.fields.rollback!==mem.fields.baselineRollback
 useEffect(()=>onLock(mem.locked),[mem.locked,onLock])
 function change(next:Layout,rollback=''){mem.change({...mem.fields,layout:JSON.stringify(next),rollback});setReview(null);setAck(false)}
 async function save(){setReview(null);setAck(false);if(await mem.run({action:'save',term,target,definition:layout,baseVersion:data.version,version:draft?.version??0,rollbackVersionId:mem.fields.rollback||null}))refreshed()}
 async function inspect(){if(!draft||dirty)return;setBusy(true);setError('');setAck(false);try{setReview(await api.preview(draft.draftId))}catch{setError('Preview unavailable. Your private inputs are kept.')}finally{setBusy(false)}}
 async function publish(){if(!review||review.stale||!ack||!draft||dirty||!mem.fields.reason.trim())return;setReview(null);setAck(false);if(await mem.run({action:'publish',draftId:draft.draftId,version:draft.version,reviewHash:review.reviewHash,reason:mem.fields.reason}))refreshed()}
 return <div data-edit-form data-pending-command={mem.locked} data-unsaved-changes={dirty||!!mem.fields.reason}>
 {data.repaired?<p role="alert">A saved or published layout is no longer supported. The editor offers a safe default. Save it as a private draft, then preview and publish a repair; historical versions remain unchanged.</p>:null}
 <Panel title={'Private layout draft · '+target.label}><p>Only you can read this draft. Publishing changes presentation for the selected {target.kind}; every work destination still checks its own access. The required next-action and help area stays first.</p>
 {mem.fields.rollback?<p>Historical layout selected. Save and review it as a new publication; existing versions remain unchanged.</p>:null}
 <LayoutControls disabled={busy||mem.locked} audience="member" layout={layout} message="Administrator draft; not a device preference." onChange={change} onReset={()=>change(defaultLayout('member'))}/>
 <button className="button button--secondary" disabled={busy||mem.locked} onClick={()=>void save()}>Save private layout draft</button>{draft&&!draft.publishedVersionId?<button className="button button--secondary" disabled={busy||mem.locked||dirty} onClick={()=>void inspect()}>Preview saved layout</button>:null}
 <LayoutPreview layout={layout}/><p><label>Reason for publication<input className="overview-example" maxLength={2000} disabled={mem.locked} value={mem.fields.reason} onChange={e=>mem.change({...mem.fields,reason:e.target.value})}/></label></p>
 </Panel>
 {review?<Panel title="Review before publishing"><p>Published version {review.version}. {review.stale?'This saved draft is stale. Save it deliberately against the current publication before reviewing again.':'This preview binds the saved draft and current publication.'}</p><h3>Before</h3>{review.previousUnsupported?<p>Unsupported historical widget configuration. This publication replaces it with the reviewed safe layout.</p>:<Description layout={review.previous}/>}<h3>After</h3><Description layout={review.proposed}/><p>Next actions, help, underlying data access and work history remain protected.</p><label><input type="checkbox" disabled={mem.locked} checked={ack} onChange={e=>setAck(e.target.checked)}/>I reviewed this exact layout change</label><button className="button" disabled={mem.locked||review.stale||!ack||!mem.fields.reason.trim()} onClick={()=>void publish()}>Publish reviewed layout</button></Panel>:null}
 {mem.pending?<button className="button" disabled={mem.busy} onClick={()=>void mem.run().then(r=>{if(r)refreshed()})}>Retry identical layout command</button>:null}{error||mem.error?<p role="alert">{error||mem.error} Inputs are kept. For a version conflict, refresh and review current publication before saving again.</p>:null}
 <Panel title="Immutable layout history">{data.history.length?<ol>{data.history.map(h=><li key={h.id}>Version {h.version} · {h.reason}{h.rollbackVersionId?' · Restored from an earlier version':''}{h.supported===false?<p>Retired or invalid widgets; this version cannot be restored.</p>:<Description layout={h.definition}/>}<button className="button button--secondary" disabled={mem.locked||h.supported===false} onClick={()=>change(h.definition,h.id)}>Restore version {h.version} as a private draft</button></li>)}</ol>:<p>No layout has been published for this target.</p>}</Panel>
 </div>
}
