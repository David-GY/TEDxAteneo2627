import {useEffect,useState} from 'react'
import {useFinDecision} from '../finance/DecisionMemory'
import type {AccountLayoutApi,AccountLayoutsData,ViewCommand} from './account-api'
import type {Layout} from './layout'
export function AccountLayouts({api,term,identity,layout,onUse,onDefault,onLock,onPublished,refresh=0}:{api:AccountLayoutApi;term:string;identity:string;layout:Layout;onUse:(layout:Layout)=>void;onDefault:(layout:Layout|null,source:string)=>void;onLock:(locked:boolean)=>void;onPublished?:(layout:Layout|null,source:string)=>void;refresh?:number}){
 const[data,setData]=useState<AccountLayoutsData|null>(null),[failed,setFailed]=useState(false),[epoch,setEpoch]=useState(0),[saved,setSaved]=useState(false)
 const mem=useFinDecision<ViewCommand,{viewId:string;version:number}>(api,'operational-view:'+term+':'+identity,{name:'',selected:''})
 useEffect(()=>{let live=true;setData(null);void api.read(term).then(v=>{if(live){setData(v);setFailed(false);onDefault(v.layout,v.source)}}).catch(()=>{if(live){setData(null);setFailed(true)}});return()=>{live=false}},[api,term,epoch,refresh,onDefault])
 useEffect(()=>{if(saved&&!mem.locked&&(mem.fields.name||mem.fields.selected))mem.change({name:'',selected:''})},[saved,mem])
 useEffect(()=>{onLock(mem.locked)},[mem.locked,onLock])
 const selected=data?.views.find(v=>v.viewId===mem.fields.selected)
 async function save(archive=false){const command:ViewCommand=archive&&selected?{term,viewId:selected.viewId,name:selected.name,layout:selected.layout,version:selected.version,archived:true}:{term,viewId:crypto.randomUUID(),name:mem.fields.name,layout,version:0,archived:false};if(await mem.run(command)){mem.change({...mem.fields,name:'',selected:''});setSaved(true);setEpoch(n=>n+1)}}
 return <section className="overview-account" aria-label="Account operational views" data-edit-form data-pending-command={mem.locked} data-unsaved-changes={!!mem.fields.name}>
 {data?.repaired?<p role="alert">A published or saved layout is no longer supported. A safe default is available. Archive an unsupported account view or ask the maintainer to repair a published layout.</p>:null}
 {data?.ambiguous?<p role="status">Several published layouts match your current scope. Using a broader default until the maintainer resolves the overlap.</p>:null}
 {failed?<p role="alert">Account views unavailable. Your next actions and device arrangement remain available. <button className="button button--secondary" onClick={()=>setEpoch(n=>n+1)}>Check account views again</button></p>:data?<details className="work-section"><summary>Saved account views</summary><p>Optional named arrangements follow your account in this term. They contain widget choices only. Next actions and help stay first.</p>
 <fieldset disabled={mem.locked}><legend>My private operational views</legend>
 {onPublished?<button className="button button--secondary" onClick={()=>onPublished(data.layout,data.source)}>Use published default</button>:null}
 <label>Saved operational view<select value={mem.fields.selected} onChange={e=>mem.change({...mem.fields,selected:e.target.value})}><option value="">Choose a saved view</option>{data.views.map(v=><option key={v.viewId} value={v.viewId}>{v.name}</option>)}</select></label>
 {selected?.supported===false?<p role="alert">This saved view contains retired widgets. Archive it and save a supported arrangement.</p>:null}
 <div className="overview-move"><button className="button button--secondary" disabled={!selected||selected.supported===false} onClick={()=>{if(selected&&selected.supported!==false)onUse(selected.layout)}}>Use saved view</button><button className="button button--secondary" disabled={!selected} onClick={()=>void save(true)}>Archive selected view</button></div>
 <label>View name<input value={mem.fields.name} maxLength={80} onChange={e=>{mem.change({...mem.fields,name:e.target.value});setSaved(false)}}/></label>
 <button className="button button--secondary" disabled={!mem.fields.name.trim()||data.views.length>=20} onClick={()=>void save()}>Save current arrangement as a new view</button><p>Up to 20 view records per account and term, including archived history.</p>
 </fieldset></details>:<p>Checking account views…</p>}
 {mem.pending?<button className="button button--secondary" disabled={mem.busy} onClick={()=>void mem.run().then(r=>{if(r){setSaved(true);setEpoch(n=>n+1)}})}>Retry identical view save</button>:null}
 {mem.error?<p role="alert">{mem.error}</p>:null}{saved?<p role="status">Account view saved.</p>:null}
 </section>
}
