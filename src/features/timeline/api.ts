import type {createSupabaseClient} from '../../lib/supabase'
import {mapCommandError,type CommandResult,type WorkReceipt} from '../../lib/commands'
import {calendarDay,displayEndDay,schedule} from './dates'
import {uuid} from './filters'
export type Named={id:string;name:string}
export type ScheduleContext={id:string;version:number;plannedStartOn:string|null;dueOn:string|null;dueAt:string|null;canSchedule:boolean}
export type TimelineItem=Omit<ScheduleContext,'canSchedule'>&{type:'task'|'deliverable'|'contribution';title:string;owner:Named;primaryUnit:Named|null;participatingUnits:Named[];phase:string|null;status:string;endOn:string|null;originalDueOn:string|null;originalDueAt:string|null;blocked:boolean;overdue:boolean;href:string}
export type TimelineResult={items:TimelineItem[];total:number;page:number;pageSize:number;options:{units:Named[];owners:Named[];phases:string[]};dependencies:{id:string;predecessorId:string;successorId:string;type:'finish_to_start'|'informational';required:boolean}[]}
export type TimelineFilters={units?:string[];owner?:string;phase?:string;type?:string;blocked?:boolean;overdue?:boolean;from?:string;to?:string;includeUnscheduled?:boolean}
export interface TimelineApi{
 read(termId:string,filters:TimelineFilters,page:number):Promise<TimelineResult|null>
 context(id:string):Promise<ScheduleContext|null>
 save(id:string,start:string|null,version:number,key:string):Promise<CommandResult<WorkReceipt>>
}
const obj=(v:unknown):v is Record<string,unknown>=>v!==null&&typeof v==='object'&&!Array.isArray(v)
const id=(v:unknown):v is string=>typeof v==='string'&&uuid.test(v)
const text=(v:unknown):v is string=>typeof v==='string'
const named=(v:unknown):v is Named=>obj(v)&&id(v.id)&&text(v.name)
const version=(v:unknown):v is number=>Number.isSafeInteger(v)&&(v as number)>0
function date(v:unknown){if(v===null)return true;if(!text(v))return false;try{return calendarDay(v)===v}catch{return false}}
function dates(r:Record<string,unknown>){try{schedule(r.plannedStartOn as string|null,r.dueOn as string|null,r.dueAt as string|null);return true}catch{return false}}
function context(v:unknown):v is ScheduleContext{return obj(v)&&id(v.id)&&version(v.version)&&date(v.plannedStartOn)&&date(v.dueOn)&&(v.dueAt===null||text(v.dueAt))&&typeof v.canSchedule==='boolean'&&dates(v)}
function item(v:unknown):v is TimelineItem{
 if(!obj(v)||!id(v.id)||!version(v.version)||!['task','deliverable','contribution'].includes(v.type as string)||!text(v.title)||!named(v.owner)||!(v.primaryUnit===null||named(v.primaryUnit))||!Array.isArray(v.participatingUnits)||!v.participatingUnits.every(named)||!(v.phase===null||text(v.phase))||!['proposed','draft','in_progress','submitted','accepted','cancelled','todo','blocked','ready_for_review','done'].includes(v.status as string)||typeof v.blocked!=='boolean'||typeof v.overdue!=='boolean'||![v.plannedStartOn,v.dueOn,v.endOn,v.originalDueOn].every(date)||!(v.dueAt===null||text(v.dueAt))||!(v.originalDueAt===null||text(v.originalDueAt))||!dates(v))return false
 const s=schedule(v.plannedStartOn as string|null,v.dueOn as string|null,v.dueAt as string|null)
 try{displayEndDay(v.originalDueOn as string|null,v.originalDueAt as string|null)}catch{return false}
 return v.endOn===(s.kind==='unscheduled'?null:s.end)&&v.href===(v.type==='deliverable'?'/deliverables/':'/tasks/')+v.id
}
export function createTimelineApi(ready:ReturnType<typeof createSupabaseClient>):TimelineApi{
 return{
 async read(termId,filters,page){const c=await ready;if(!c)throw new Error('Timeline unavailable');const{data,error}=await c.rpc('read_committee_timeline',{p_term_id:termId,p_filters:filters,p_page:page,p_page_size:50});if(error)throw new Error('Timeline unavailable');if(data===null)return null;const r=data as unknown
 if(!obj(r)||!Array.isArray(r.items)||r.items.length>50||!r.items.every(item)||new Set(r.items.map(x=>x.id)).size!==r.items.length||!Number.isSafeInteger(r.total)||(r.total as number)<r.items.length||r.page!==page||r.pageSize!==50||!obj(r.options)||!Array.isArray(r.options.units)||!r.options.units.every(named)||!Array.isArray(r.options.owners)||!r.options.owners.every(named)||!Array.isArray(r.options.phases)||!r.options.phases.every(text)||!Array.isArray(r.dependencies))throw new Error('Timeline unavailable')
 const ids=new Set(r.items.map(x=>x.id));if(!r.dependencies.every(e=>obj(e)&&id(e.id)&&ids.has(e.predecessorId as string)&&ids.has(e.successorId as string)&&e.predecessorId!==e.successorId&&['finish_to_start','informational'].includes(e.type as string)&&typeof e.required==='boolean'&&(e.type!=='informational'||!e.required)))throw new Error('Timeline unavailable')
 return r as unknown as TimelineResult},
 async context(workId){if(!id(workId))return null;const c=await ready;if(!c)throw new Error('Schedule unavailable');const{data,error}=await c.rpc('read_work_schedule',{p_work_item_id:workId});if(error)throw new Error('Schedule unavailable');if(data===null)return null;if(!context(data)||data.id!==workId)throw new Error('Schedule unavailable');return data},
 async save(workId,start,expected,key){try{if(!id(workId)||!id(key)||!version(expected)||!date(start))throw{code:'22023'};const c=await ready;if(!c)throw{code:'COMMAND_UNAVAILABLE'};const{data,error}=await c.rpc('update_work_schedule',{p_work_item_id:workId,p_planned_start_on:start!,p_expected_version:expected,p_request_id:key});if(error)return{ok:false,error:mapCommandError(error)};if(!obj(data)||data.workItemId!==workId||!version(data.version))throw{code:'COMMAND_UNAVAILABLE'};return{ok:true,value:data as WorkReceipt}}catch(e){return{ok:false,error:mapCommandError(e)}}}
 }
}
