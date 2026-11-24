import {navigationItems,getVisibleNavigation} from '../../../app/navigation'
import {TextField} from '../../../components/TextField'
import {siteNavigationIds,type SitePresentation,type SiteBlock,applyNavigationPresentation} from './presentation'
const items=navigationItems.filter(x=>siteNavigationIds.includes(x.id))
export function SiteControls({value,disabled,change}:{value:SitePresentation;disabled:boolean;change:(v:SitePresentation)=>void}){
 const order=[...value.order,...siteNavigationIds.filter(id=>!value.order.includes(id))]
 function move(id:string,delta:number){const next=[...order],index=next.indexOf(id),to=index+delta;if(to<0||to>=next.length)return;[next[index],next[to]]=[next[to],next[index]];change({...value,order:next})}
 function block(index:number,patch:Partial<SiteBlock>){change({...value,blocks:value.blocks.map((b,i)=>i===index?{...b,...patch}:b)})}
 return <fieldset disabled={disabled}><legend>Guidance, navigation order and interface accent</legend>
 <div><label htmlFor="site-accent">Interface accent</label><select id="site-accent" value={value.accent} onChange={e=>change({...value,accent:e.target.value as SitePresentation['accent']})}><option value="#b82320">Workspace red (default)</option><option value="#252624">Ink</option></select></div><p>Both fixed accents retain accessible contrast and visible focus. Karla and approved logo colors are protected.</p>
 <ol>{order.map((id,index)=><li key={id}>{items.find(x=>x.id===id)?.label}<div className="auth-actions"><button className="button button--secondary" disabled={index===0} onClick={()=>move(id,-1)} aria-label={'Move '+items.find(x=>x.id===id)?.label+' up'}>Move up</button><button className="button button--secondary" disabled={index===order.length-1} onClick={()=>move(id,1)} aria-label={'Move '+items.find(x=>x.id===id)?.label+' down'}>Move down</button></div></li>)}</ol>
 <p>Guidance is common to members and invited guests. Do not enter private work, finance or personal data. Links use existing destinations and never grant access.</p>
 {value.blocks.map((b,index)=><fieldset key={b.id}><legend>Guidance block {index+1}</legend><label htmlFor={'block-kind-'+b.id}>Block {index+1} type</label><select id={'block-kind-'+b.id} value={b.kind} onChange={e=>{const kind=e.target.value as SiteBlock['kind'];const next={...b,kind};if(kind==='text')delete next.href;else next.href??='/resources';change({...value,blocks:value.blocks.map((x,i)=>i===index?next:x)})}}>{['text','link','card'].map(x=><option key={x}>{x}</option>)}</select>
 <TextField id={'block-title-'+b.id} label={'Block '+(index+1)+' title'} maxLength={200} value={b.title} onChange={e=>block(index,{title:e.target.value})}/><TextField id={'block-body-'+b.id} label={'Block '+(index+1)+' guidance'} maxLength={2000} value={b.body} onChange={e=>block(index,{body:e.target.value})}/>
 {b.kind!=='text'?<div><label htmlFor={'block-destination-'+b.id}>Block {index+1} destination</label><select id={'block-destination-'+b.id} value={b.href} onChange={e=>block(index,{href:e.target.value})}>{items.map(x=><option key={x.id} value={x.href}>{x.label}</option>)}</select></div>:null}
 <button className="button button--secondary" onClick={()=>change({...value,blocks:value.blocks.filter((_,i)=>i!==index)})}>Remove block {index+1}</button>
 {index>0?<button className="button button--secondary" onClick={()=>{const blocks=[...value.blocks];[blocks[index-1],blocks[index]]=[blocks[index],blocks[index-1]];change({...value,blocks})}}>Move block {index+1} up</button>:null}</fieldset>)}
 <button className="button button--secondary" disabled={value.blocks.length>=12} onClick={()=>change({...value,blocks:[...value.blocks,{id:'guidance_'+crypto.randomUUID().replaceAll('-',''),kind:'text',title:'New guidance',body:'Describe shared guidance.'}]})}>Add guidance block</button>
 </fieldset>
}
export function SiteRolePreview({value,audience}:{value:SitePresentation;audience:'member'|'head'|'guest'}){
 const visible=getVisibleNavigation({audience:audience==='guest'?'guest':'core',capabilities:audience==='head'?['committee.manage']:[]}),nav=applyNavigationPresentation(visible,value),blocks=value.blocks.filter(b=>b.kind==='text'||visible.some(x=>x.href===b.href))
 return <section className={value.accent==='#252624'?'panel site-theme--ink':'panel'} aria-label={audience+' synthetic preview'}><h3>{audience} · synthetic presentation only</h3><p>Fictional layout; no impersonation, live records or access grants. Deep links and work checks remain unchanged.</p><ul>{nav.map(x=><li key={x.id}>{x.label} <small>{x.href}</small></li>)}</ul>{blocks.map(b=><div key={b.id}><h4>{b.title}</h4><p>{b.body}</p></div>)}</section>
}
