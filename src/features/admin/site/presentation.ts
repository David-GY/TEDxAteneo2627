import type {NavigationItem} from '../../../app/navigation'

const editable=['overview','deliverables','tasks','working','requests','calendar','resources','people']
const destinations=['/','/deliverables','/tasks','/working-together','/requests','/calendar','/resources','/people']
export type SiteBlock={id:string;kind:'text'|'link'|'card';title:string;body:string;href?:string}
export type SitePresentation={schemaVersion:1;labels:Record<string,string>;order:string[];accent:'#b82320'|'#252624';blocks:SiteBlock[]}
const object=(x:unknown):x is Record<string,unknown>=>!!x&&typeof x==='object'&&!Array.isArray(x)&&(Object.getPrototypeOf(x)===Object.prototype||Object.getPrototypeOf(x)===null)
const closed=(x:Record<string,unknown>,keys:string[])=>Object.keys(x).every(k=>keys.includes(k))
const text=(x:unknown,max:number)=>typeof x==='string'&&x.trim().length>0&&Array.from(x).length<=max&&Array.from(x).every(ch=>ch.charCodeAt(0)>=32&&ch.charCodeAt(0)!==127&&ch!=='<'&&ch!=='>')
// Presentation only. The publication adapter must repeat these constraints on the server.
// No licensed identity, permission, route or executable styling fields exist in this schema.
export function validSitePresentation(x:unknown):x is SitePresentation{
 if(!object(x)||!closed(x,['schemaVersion','labels','order','accent','blocks'])||x.schemaVersion!==1||!['#b82320','#252624'].includes(String(x.accent))||!object(x.labels)||!Object.entries(x.labels).every(([k,v])=>editable.includes(k)&&text(v,80))||!Array.isArray(x.order)||x.order.length>editable.length||!x.order.every(k=>typeof k==='string'&&editable.includes(k))||new Set(x.order).size!==x.order.length||!Array.isArray(x.blocks)||x.blocks.length>12)return false
 const ids=new Set<string>()
 for(const b of x.blocks){if(!object(b)||!closed(b,['id','kind','title','body','href'])||typeof b.id!=='string'||!/^[a-z][a-z0-9_]{0,59}$/.test(b.id)||ids.has(b.id)||!['text','link','card'].includes(String(b.kind))||!text(b.title,200)||!text(b.body,2000))return false
  if(b.kind==='text'?b.href!==undefined:typeof b.href!=='string'||!destinations.includes(b.href))return false
  ids.add(b.id)
 }
 return new TextEncoder().encode(JSON.stringify(x)).length<=50000
}
export function applyNavigationPresentation(visible:readonly NavigationItem[],config:unknown):NavigationItem[]{
 if(!validSitePresentation(config))throw Error('Site wording or theme is invalid. Keep plain text, supported destinations and accessible colors.')
 const position=(id:string)=>{const n=config.order.indexOf(id);return n<0?config.order.length:n}
 // Sort only within incumbent groups; never promote role tools into everyday navigation.
 return visible.map((item,index)=>({item:{...item,label:config.labels[item.id]??item.label},index})).sort((a,b)=>a.item.group===b.item.group?position(a.item.id)-position(b.item.id)||a.index-b.index:a.index-b.index).map(x=>x.item)
}
