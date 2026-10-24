import type { createSupabaseClient } from '../../lib/supabase'
import { mapCommandError, type CommandResult, type WorkReceipt } from '../../lib/commands'
import type { Named } from './api'
export type DeliverableState = 'proposed' | 'draft' | 'in_progress' | 'submitted' | 'accepted' | 'cancelled'
export type DeliverableAction = 'approve_proposal' | 'start' | 'submit' | 'accept' | 'revise' | 'cancel'
export type DeliverableData = { title:string; summary:string; body:string; ownerId:string; leadUnitId:string; phase:string; outcome:string; criteria:string; dueOn:string|null; dueAt:string|null; classification:'ordinary'|'restricted'; reason:string }
export type AuthoringContext = { memberId:string; version:number|null; criteriaRevision:number|null; state:DeliverableState|null; manager:boolean; editable:boolean; actions:DeliverableAction[]; owners:Named[]; units:(Named&{canManage:boolean})[]; queue:{id:string;title:string}[]; data:DeliverableData|null }
export type AuthoringCommand =
  | {command:'create';termId:string;data:DeliverableData;propose:boolean}
  | {command:'update';id:string;data:DeliverableData;version:number}
  | {command:'transition';id:string;action:DeliverableAction;reason:string;evidence:string|null;version:number;criteriaRevision?:number}
export interface DeliverableCommands { read(termId:string,id?:string):Promise<AuthoringContext|null>; execute(input:AuthoringCommand,key:string):Promise<CommandResult<WorkReceipt>> }
const states=['proposed','draft','in_progress','submitted','accepted','cancelled']
const actions=['approve_proposal','start','submit','accept','revise','cancel']
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const object=(v:unknown):v is Record<string,unknown>=>!!v&&typeof v==='object'
const named=(v:unknown)=>object(v)&&typeof v.id==='string'&&uuid.test(v.id)&&typeof v.name==='string'
function data(v:unknown):boolean {return object(v)&&['title','summary','body','ownerId','leadUnitId','phase','outcome','criteria','classification','reason'].every(k=>typeof v[k]==='string')&&['dueOn','dueAt'].every(k=>v[k]===null||typeof v[k]==='string')}
export function createDeliverableCommands(ready:ReturnType<typeof createSupabaseClient>):DeliverableCommands {
  return {
    async read(termId,id){
      try{
        const client=await ready;if(!client)throw new Error()
        const {data:r,error}=await client.rpc('read_deliverable_authoring',{p_term_id:termId,p_work_item_id:id??null})
        if(error)throw new Error();if(r===null)return null
        if(!object(r)||typeof r.memberId!=='string'||!uuid.test(r.memberId)||!(r.version===null||(Number.isInteger(r.version)&&(r.version as number)>0))
          ||!(r.state===null||states.includes(r.state as string))||typeof r.manager!=='boolean'||typeof r.editable!=='boolean'
          ||!(r.criteriaRevision===null||Number.isInteger(r.criteriaRevision))||!Array.isArray(r.actions)||!r.actions.every(a=>typeof a==='string'&&actions.includes(a))||!Array.isArray(r.owners)||!r.owners.every(named)
          ||!Array.isArray(r.units)||!r.units.every(u=>named(u)&&object(u)&&typeof u.canManage==='boolean')
          ||!Array.isArray(r.queue)||!r.queue.every(q=>object(q)&&typeof q.id==='string'&&uuid.test(q.id)&&typeof q.title==='string')||!(r.data===null||data(r.data)))throw new Error()
        return r as unknown as AuthoringContext
      }catch{throw new Error('Authoring access could not be loaded. Reload to check access and connection.')}
    },
    async execute(input,key){
      try{
        const client=await ready;if(!client)throw {code:'COMMAND_UNAVAILABLE'}
        const result=input.command==='create'?await client.rpc('create_deliverable',{p_term_id:input.termId,p_data:input.data,p_propose:input.propose,p_request_id:key})
          :input.command==='update'?await client.rpc('update_deliverable',{p_work_item_id:input.id,p_data:input.data,p_expected_version:input.version,p_request_id:key})
          :await client.rpc('transition_deliverable',{p_work_item_id:input.id,p_action:input.action,p_reason:input.reason,p_evidence:input.evidence??'',p_expected_version:input.version,p_request_id:key,p_criteria_revision:input.criteriaRevision??null})
        if(result.error)return {ok:false,error:mapCommandError(result.error)}
        const r=result.data;if(!object(r)||typeof r.workItemId!=='string'||!uuid.test(r.workItemId)||!Number.isInteger(r.version)||(r.version as number)<1) return {ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}
        return {ok:true,value:r as WorkReceipt}
      }catch(e){return {ok:false,error:mapCommandError(e)}}
    },
  }
}
