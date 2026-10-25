import type {createSupabaseClient} from '../../lib/supabase'
import {mapCommandError,type CommandResult} from '../../lib/commands'
import type {Json} from '../../lib/database.types'
import type {FormDefinition} from './catalog/api'
import {validDefinition,type FormValues,type Choice} from '../forms/validation'
export type RequestState='draft'|'revision_draft'|'paused'|'in_review'|'needs_revision'|'approved'|'rejected'|'completed'|'cancelled'
export type RequestReceipt={requestId:string;termId:string;version:number;state:RequestState;revision:number;trackingId:string|null}
export type RequestInput={id:string;values:FormValues;centavos:number|null;requestedOn:string|null;title:string;version:number}
export type RequestCommand={kind:'create';termId:string;typeId:string;formVersionId:string;workflowVersionId:string;title:string}|{kind:'save'|'submit'|'revise';input:RequestInput}|{kind:'begin'|'cancel';id:string;version:number;reason:string}
export type RequestDraft={values:FormValues;snapshots:Record<string,Choice[]>;requestedCentavos:number|null;requestedOn:string|null}
export type RequestView={id:string;termId:string;title:string;version:number;typeId:string;typeLabel:string;serviceLabel:string|null;state:RequestState;revision:number;trackingId:string|null;originalRequestedOn:string|null;acceptedOn:string|null;formVersionId:string;formVersion:number;workflowVersionId:string;workflowVersion:number;form:FormDefinition;classification:'ordinary'|'restricted';canEdit:boolean;canSubmit:boolean;canRevise:boolean;canCancel:boolean;nextAction:string;draft:RequestDraft|null;
 selected:(RequestDraft&{revision:number;title:string;submittedAt:string;manifestHash:string;files:{id:string;name:string;size:number;mime:string;sha256:string}[]})|null;
 revisionHeaders:{revision:number;title:string;requestedOn:string|null;submittedAt:string}[];history:{page:number;pageSize:25;total:number;items:{action:string;revision:number;actor:string;reason:string;at:string}[]}}
export type RequestList={page:number;pageSize:20;total:number;items:{id:string;termId:string;title:string;state:RequestState;trackingId:string|null;typeLabel:string;revision:number;requestedOn:string|null;acceptedOn:string|null;updatedAt:string}[]}
export interface RequestsApi{run(command:RequestCommand,key:string):Promise<CommandResult<RequestReceipt>>;read(termId:string,id:string,revision?:number,page?:number):Promise<RequestView|null>;list(termId:string,page:number):Promise<RequestList|null>}
const uuid=(v:unknown)=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)
const integer=(v:unknown)=>Number.isSafeInteger(v)&&(v as number)>=0
const state=(v:unknown)=>['draft','revision_draft','paused','in_review','needs_revision','approved','rejected','completed','cancelled'].includes(String(v))
const object=(v:unknown)=>!!v&&typeof v==='object'&&!Array.isArray(v)
const date=(v:unknown)=>v===null||typeof v==='string'&&Number.isFinite(Date.parse(v))
const tracking=(v:unknown)=>v===null||typeof v==='string'&&/^[A-Z][A-Z0-9_-]{0,39}-[0-9]{3,16}$/.test(v)
const cents=(v:unknown)=>v===null||integer(v)
function receipt(v:unknown):v is RequestReceipt{const r=v as RequestReceipt;return !!r&&uuid(r.requestId)&&uuid(r.termId)&&integer(r.version)&&r.version>0&&state(r.state)&&integer(r.revision)&&tracking(r.trackingId)&&(r.revision===0?r.trackingId===null:r.trackingId!==null)}
function draft(d:RequestDraft|null){return d===null||d&&object(d.values)&&object(d.snapshots)&&cents(d.requestedCentavos)&&date(d.requestedOn)}
export function createRequestsApi(ready:ReturnType<typeof createSupabaseClient>):RequestsApi{
 async function client(){const c=await ready;if(!c)throw{code:'COMMAND_UNAVAILABLE'};return c}
 return{
 async run(command,key){try{const c=await client();let result;
  if(command.kind==='create')result=await c.rpc('create_request_draft',{p_term_id:command.termId,p_type_id:command.typeId,p_form_version_id:command.formVersionId,p_workflow_version_id:command.workflowVersionId,p_title:command.title,p_request_id:key});
  else if('input'in command){const i=command.input,args={p_work_item_id:i.id,p_values:i.values as Json,p_requested_centavos:i.centavos!,p_requested_on:i.requestedOn!,p_title:i.title,p_expected_version:i.version,p_request_id:key};result=command.kind==='save'?await c.rpc('save_request_draft',args):command.kind==='submit'?await c.rpc('submit_request',args):await c.rpc('revise_request',args)}
  else result=command.kind==='begin'?await c.rpc('begin_request_revision',{p_work_item_id:command.id,p_expected_version:command.version,p_request_id:key}):await c.rpc('cancel_request',{p_work_item_id:command.id,p_expected_version:command.version,p_reason:command.reason,p_request_id:key});
  if(result.error)return{ok:false,error:mapCommandError(result.error)};if(!receipt(result.data))throw{code:'COMMAND_UNAVAILABLE'};const r=result.data;if(command.kind==='create'?r.termId!==command.termId:r.requestId!==('input'in command?command.input.id:command.id))throw{code:'COMMAND_UNAVAILABLE'};return{ok:true,value:r};
 }catch(e){return{ok:false,error:mapCommandError(e)}}},
 async read(termId,id,revision,page=1){try{const{data,error}=await(await client()).rpc('read_request',{p_term_id:termId,p_work_item_id:id,p_revision:revision??null,p_history_page:page});if(error)throw error;if(data===null)return null;const r=data as unknown as RequestView;
  if(!r||r.id!==id||r.termId!==termId||!uuid(r.id)||!integer(r.version)||r.version<1||!state(r.state)||!integer(r.revision)||!tracking(r.trackingId)||!['ordinary','restricted'].includes(r.classification)||!validDefinition(r.form,r.classification==='restricted')||!['title','typeLabel','nextAction'].every(k=>typeof r[k as keyof RequestView]==='string')||!['canEdit','canSubmit','canRevise','canCancel'].every(k=>typeof r[k as keyof RequestView]==='boolean')||![r.formVersionId,r.workflowVersionId,r.typeId].every(uuid)||![r.formVersion,r.workflowVersion].every(v=>integer(v)&&v>0)||![r.originalRequestedOn,r.acceptedOn].every(date)||!draft(r.draft)||r.selected!==null&&(!draft(r.selected)||!integer(r.selected.revision)||!Array.isArray(r.selected.files)||r.selected.files.length>20||!r.selected.files.every(f=>uuid(f.id)&&typeof f.name==='string'&&integer(f.size)&&typeof f.sha256==='string'))||!Array.isArray(r.revisionHeaders)||r.revisionHeaders.length>100||!r.revisionHeaders.every(h=>integer(h.revision)&&typeof h.title==='string'&&date(h.requestedOn)&&date(h.submittedAt))||!r.history||r.history.page!==page||r.history.pageSize!==25||!integer(r.history.total)||!Array.isArray(r.history.items)||r.history.items.length>25||!r.history.items.every(h=>typeof h.action==='string'&&typeof h.actor==='string'&&typeof h.reason==='string'&&integer(h.revision)&&date(h.at)))throw Error();return r;
 }catch{throw Error('Request could not load. Check current access or connection and retry.')}},
 async list(termId,page){try{const{data,error}=await(await client()).rpc('list_my_requests',{p_term_id:termId,p_page:page});if(error)throw error;if(data===null)return null;const r=data as unknown as RequestList;if(!r||r.page!==page||r.pageSize!==20||!integer(r.total)||!Array.isArray(r.items)||r.items.length>20||!r.items.every(i=>uuid(i.id)&&i.termId===termId&&typeof i.title==='string'&&typeof i.typeLabel==='string'&&state(i.state)&&tracking(i.trackingId)&&integer(i.revision)&&date(i.requestedOn)&&date(i.acceptedOn)))throw Error();return r}catch{throw Error('Your requests could not load. Check access or connection and retry.')}},
 }
}
