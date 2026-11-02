import type {createSupabaseClient} from '../../lib/supabase'
import type {Mapping} from './csv'
export type ImportInput={header:string[];mapping:Mapping;rows:string[][]}
export type ImportRef={draftId:string;version:number;state:'draft'|'committed'}
export type ImportValues={title:string;assignee:string|null;dueOn:string|null;dueAt:string|null}
export type ImportPreview=Pick<ImportRef,'draftId'|'version'>&{listName:string;unitName:string;valid:boolean;reviewHash:string;rows:{record:number;sourceKey:string;operation:'create'|'update'|'unchanged';targetId:string|null;reference:string|null;expectedWorkVersion:number|null;assigneeId:string|null;before:ImportValues|null;after:ImportValues;errors:string[]}[]}
export type ImportReceipt=ImportRef&{created:number;updated:number;unchanged:number;items:{sourceKey:string;workItemId:string;title:string;reference:string;version:number;action:'create'|'update'|'unchanged';href:string}[]}
export type ImportRead={units:{id:string;name:string}[];drafts:(ImportRef&{listName:string})[];draft:(ImportRef&{unitId:string;listName:string;input:ImportInput;receipt:ImportReceipt|null})|null}
export interface TaskImportsApi{
 read(term:string,id?:string):Promise<ImportRead>
 save(term:string,unit:string,list:string,input:ImportInput,id:string|null,version:number,key:string):Promise<ImportRef>
 preview(id:string,version:number):Promise<ImportPreview>
 commit(term:string,id:string,version:number,hash:string,key:string):Promise<ImportReceipt>
}
export class ImportError extends Error{constructor(public kind:'denied'|'validation'|'conflict'|'connection'){super('Import unavailable')}}
const uuid=(x:unknown)=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x)
const count=(x:unknown)=>typeof x==='number'&&Number.isSafeInteger(x)&&x>=0
const ref=(v:ImportRef)=>!!v&&uuid(v.draftId)&&count(v.version)&&v.version>0&&['draft','committed'].includes(v.state)
const optionalDate=(v:unknown)=>v===null||typeof v==='string'&&Number.isFinite(Date.parse(v))
const values=(v:ImportValues)=>!!v&&typeof v.title==='string'&&(v.assignee===null||typeof v.assignee==='string')&&optionalDate(v.dueOn)&&optionalDate(v.dueAt)
const input=(v:ImportInput)=>!!v&&Array.isArray(v.header)&&v.header.every(h=>typeof h==='string')&&!!v.mapping&&Object.values(v.mapping).every(h=>typeof h==='string')&&Array.isArray(v.rows)&&v.rows.length<=50&&v.rows.every(r=>Array.isArray(r)&&r.every(c=>typeof c==='string'))
function receipt(v:ImportReceipt,term:string){return ref(v)&&v.state==='committed'&&[v.created,v.updated,v.unchanged].every(count)&&Array.isArray(v.items)&&v.items.length<=50&&v.items.length===v.created+v.updated+v.unchanged&&v.items.every(r=>!!r&&typeof r.sourceKey==='string'&&uuid(r.workItemId)&&typeof r.title==='string'&&typeof r.reference==='string'&&r.reference.length>0&&r.reference.length<=120&&count(r.version)&&r.version>0&&['create','update','unchanged'].includes(r.action)&&r.href==='/tasks/'+r.workItemId+'?term='+term)&&v.items.filter(r=>r.action==='create').length===v.created&&v.items.filter(r=>r.action==='update').length===v.updated}
export function createTaskImportsApi(ready:ReturnType<typeof createSupabaseClient>):TaskImportsApi{
 async function rpc(name:'read_task_import'|'save_task_import'|'preview_task_import'|'commit_task_import',args:Record<string,unknown>){
  const c=await ready;if(!c)throw new ImportError('connection')
  let reply;try{reply=await c.rpc(name,args as never)}catch{throw new ImportError('connection')}
  if(reply.error)throw new ImportError(reply.error.code==='42501'?'denied':reply.error.code==='40001'?'conflict':['22023','22007','22008','22P02','55000'].includes(reply.error.code)?'validation':'connection')
  return reply.data
 }
 return{
  async read(term,id){const v=await rpc('read_task_import',{p_term_id:term,p_draft_id:id??null})as unknown as ImportRead
   if(!v||!Array.isArray(v.units)||!v.units.every(u=>!!u&&uuid(u.id)&&typeof u.name==='string')||!Array.isArray(v.drafts)||!v.drafts.every(d=>ref(d)&&typeof d.listName==='string')||v.draft!==null&&(!ref(v.draft)||!uuid(v.draft.unitId)||typeof v.draft.listName!=='string'||!input(v.draft.input)||v.draft.receipt!==null&&!receipt(v.draft.receipt,term)))throw new ImportError('connection');return v},
  async save(term,unit,list,data,id,version,key){const v=await rpc('save_task_import',{p_term_id:term,p_unit_id:unit,p_list_name:list,p_input:data,p_draft_id:id,p_expected_version:version,p_request_id:key})as unknown as ImportRef;if(!ref(v))throw new ImportError('connection');return v},
  async preview(id,version){const v=await rpc('preview_task_import',{p_draft_id:id,p_expected_version:version})as unknown as ImportPreview
   if(!v||v.draftId!==id||v.version!==version||typeof v.valid!=='boolean'||typeof v.listName!=='string'||typeof v.unitName!=='string'||!/^([a-f0-9]{64})$/.test(v.reviewHash)||!Array.isArray(v.rows)||v.rows.length<1||v.rows.length>50||!v.rows.every(r=>!!r&&count(r.record)&&r.record>=2&&typeof r.sourceKey==='string'&&['create','update','unchanged'].includes(r.operation)&&(r.targetId===null||uuid(r.targetId))&&(r.reference===null||typeof r.reference==='string')&&(r.expectedWorkVersion===null||count(r.expectedWorkVersion))&&(r.before===null||values(r.before))&&values(r.after)&&Array.isArray(r.errors)&&r.errors.every(e=>typeof e==='string'))||v.valid&&v.rows.some(r=>r.errors.length))throw new ImportError('connection');return v},
  async commit(term,id,version,hash,key){const v=await rpc('commit_task_import',{p_draft_id:id,p_expected_version:version,p_review_hash:hash,p_request_id:key})as unknown as ImportReceipt;if(!receipt(v,term)||v.draftId!==id)throw new ImportError('connection');return v},
 }
}
