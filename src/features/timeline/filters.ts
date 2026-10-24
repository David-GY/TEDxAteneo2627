import {calendarDay,manilaDay,type Scale} from './dates'
export const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
export type TimelineQuery={anchor:string;scale:Scale;view:'chart'|'list';units:string[];owner:string;phase:string;type:''|'task'|'deliverable'|'contribution';blocked:boolean;overdue:boolean;includeUnscheduled:boolean;page:number}
export function parseTimelineQuery(search:string,today=manilaDay(new Date().toISOString())):TimelineQuery{
 const p=new URLSearchParams(search);let anchor=today
 try{if(p.get('date'))anchor=calendarDay(p.get('date')!)}catch{/* Retain Manila today for malformed dates. */}
 const page=Number(p.get('page')??1),type=p.get('type'),phase=p.get('phase')??''
 return{anchor,scale:p.get('scale')==='week'?'week':'month',view:p.get('view')==='list'?'list':'chart',units:[...new Set(p.getAll('unit').filter(x=>uuid.test(x)))].sort().slice(0,20),owner:uuid.test(p.get('owner')??'')?p.get('owner')!:'',phase:phase.length<=80&&!Array.from(phase).some(c=>c.charCodeAt(0)<32||c.charCodeAt(0)===127)?phase:'',type:type==='task'||type==='deliverable'||type==='contribution'?type:'',blocked:p.get('blocked')==='1',overdue:p.get('overdue')==='1',includeUnscheduled:p.get('unscheduled')!=='0',page:Number.isSafeInteger(page)&&page>=1&&page<=10000?page:1}
}
export function timelineSearch(q:TimelineQuery):string{
 const p=new URLSearchParams({date:q.anchor,scale:q.scale,view:q.view})
 for(const unit of q.units)p.append('unit',unit)
 for(const k of ['owner','phase','type']as const)if(q[k])p.set(k,q[k])
 for(const k of ['blocked','overdue']as const)if(q[k])p.set(k,'1')
 if(!q.includeUnscheduled)p.set('unscheduled','0');if(q.page>1)p.set('page',String(q.page))
 return'?'+p.toString()
}
