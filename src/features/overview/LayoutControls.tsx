import {allowedWidgets,moveWidget,type Layout,type LayoutAudience} from './layout'
import {useRef,useState} from 'react'
export function LayoutControls({layout,audience,message,onChange,onReset}:{layout:Layout;audience:LayoutAudience;message:string;onChange:(layout:Layout)=>void;onReset:()=>void}){
 const catalog=allowedWidgets(audience),controls=useRef<HTMLFieldSetElement>(null),[announcement,setAnnouncement]=useState('')
 function move(id:string,direction:-1|1){
  const next=moveWidget(layout,id,direction),index=next.widgets.findIndex(w=>w.id===id)
  onChange(next);setAnnouncement(`${catalog.find(c=>c.id===id)!.label} moved to position ${index+1} of ${next.widgets.length}.`)
  requestAnimationFrame(()=>{const row=controls.current?.querySelector(`[data-control="${id}"]`);const target=row?.querySelector<HTMLButtonElement>(`button[data-direction="${direction}"]:not(:disabled)`)??row?.querySelector<HTMLButtonElement>('button:not(:disabled)');target?.focus()})
 }
 return <details className="work-section overview-arrangement"><summary>Arrange my overview</summary>
 <p>Optional: arrange secondary views on this device. Next actions and help always stay first. This changes your view only; it does not publish a role layout or grant access.</p>
 <p role="status">{message}</p><p aria-live="polite">{announcement}</p><fieldset ref={controls}><legend>Secondary views</legend>
 {layout.widgets.map((w,index)=><div className="overview-widget-control" data-control={w.id} key={w.id}>
 <strong>{catalog.find(c=>c.id===w.id)!.label}</strong>
 <label>Size for {catalog.find(c=>c.id===w.id)!.label}<select value={w.size} onChange={e=>onChange({...layout,widgets:layout.widgets.map(v=>v.id===w.id?{...v,size:e.target.value as 'wide'|'compact'}:v)})}><option value="wide">Full width</option><option value="compact">Compact on wide screens</option></select></label>
 <div className="overview-move"><button className="button button--secondary" data-direction="-1" aria-label={`Move ${catalog.find(c=>c.id===w.id)!.label} up`} disabled={index===0} onClick={()=>move(w.id,-1)}>Move up</button>
 <button className="button button--secondary" data-direction="1" aria-label={`Move ${catalog.find(c=>c.id===w.id)!.label} down`} disabled={index===layout.widgets.length-1} onClick={()=>move(w.id,1)}>Move down</button>
 <button className="button button--secondary" aria-label={`Remove ${catalog.find(c=>c.id===w.id)!.label}`} onClick={()=>onChange({...layout,widgets:layout.widgets.filter(v=>v.id!==w.id)})}>Remove</button></div></div>)}
 <div className="overview-move">{catalog.filter(c=>!layout.widgets.some(w=>w.id===c.id)).map(c=><button className="button button--secondary" key={c.id} onClick={()=>onChange({...layout,widgets:[...layout.widgets,{id:c.id,size:'compact'}]})}>Add {c.label}</button>)}</div>
 </fieldset><button className="button button--secondary" onClick={onReset}>Restore default view</button>
 </details>
}
