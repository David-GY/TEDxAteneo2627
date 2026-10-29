import {widgetCatalog,type WidgetId} from '../../app/widgetCatalog'
export type LayoutAudience='member'|'guest'
export type Layout={version:1;widgets:{id:WidgetId;size:'wide'|'compact'}[]}
export const defaultLayout=(audience:LayoutAudience):Layout=>({version:1,widgets:[{id:'waiting',size:'wide'},{id:audience==='guest'?'resources':'calendar',size:'compact'}]})
const plain=(v:unknown):v is Record<string,unknown>=>!!v&&typeof v==='object'&&(Object.getPrototypeOf(v)===Object.prototype||Object.getPrototypeOf(v)===null)
export function validateLayout(value:unknown,audience:LayoutAudience):value is Layout{
 if(!plain(value)||Object.keys(value).some(k=>!['version','widgets'].includes(k))||value.version!==1||!Array.isArray(value.widgets)||value.widgets.length>widgetCatalog.length)return false
 const allowed=allowedWidgets(audience)
 return Array.from(value.widgets).every(w=>plain(w)&&Object.keys(w).length===2&&Object.keys(w).every(k=>['id','size'].includes(k))&&allowed.some(a=>a.id===w.id)&&typeof w.size==='string'&&['wide','compact'].includes(w.size))&&new Set(value.widgets.map(w=>w.id)).size===value.widgets.length
}
export const resolveLayout=(value:unknown,audience:LayoutAudience)=>({layout:validateLayout(value,audience)?{version:1 as const,widgets:value.widgets.map(w=>({...w}))}:defaultLayout(audience),repaired:value!==null&&value!==undefined&&!validateLayout(value,audience)})
export function moveWidget(layout:Layout,id:string,direction:-1|1):Layout{
 const widgets=layout.widgets.map(w=>({...w})),index=widgets.findIndex(w=>w.id===id),next=index+direction
 if(index>=0&&next>=0&&next<widgets.length)[widgets[index],widgets[next]]=[widgets[next],widgets[index]]
 return{version:1,widgets}
}
export const viewStorageKey=(org:string,term:string,subject:string)=>JSON.stringify(['tedx-layout-v1',org,term,subject])
export const allowedWidgets=(audience:LayoutAudience)=>widgetCatalog.filter(w=>audience==='member'||w.guest)
