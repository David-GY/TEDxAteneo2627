import type {createSupabaseClient} from '../../lib/supabase'
import {ImportError,type ImportInput,type ImportRef} from './task-import-api'
export type RosterValues={name:string;email:string;status:'active';joinedAt:string;endsAt:string}
export type RosterPreview=Pick<ImportRef,'draftId'|'version'>&{termId:string;termLabel:string;listName:string;joinedAt:string;endsAt:string;valid:boolean;reviewHash:string;rows:{record:number;sourceKey:string;operation:'create'|'unchanged';targetId:string|null;memberId:string|null;expectedMembershipVersion:number|null;expectedMemberVersion:number|null;before:RosterValues|null;after:RosterValues;errors:string[]}[]}
export type RosterReceipt=ImportRef&{termId:string;created:number;unchanged:number;items:{sourceKey:string;membershipId:string;memberId:string;name:string;action:'create'|'unchanged'}[]}
export type RosterRead={drafts:(ImportRef&{listName:string})[];draft:(ImportRef&{termId:string;listName:string;joinedAt:string;endsAt:string;input:ImportInput;receipt:RosterReceipt|null})|null}
export interface RosterImportsApi{
 read(term:string,id?:string):Promise<RosterRead>
 save(term:string,list:string,joined:string,ends:string,input:ImportInput,id:string|null,version:number,key:string):Promise<ImportRef>
 preview(term:string,id:string,version:number):Promise<RosterPreview>
 commit(term:string,id:string,version:number,hash:string,reason:string,key:string):Promise<RosterReceipt>
}
const uuid=(x:unknown)=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x)
const count=(x:unknown)=>typeof x==='number'&&Number.isSafeInteger(x)&&x>=0
const ref=(v:ImportRef)=>!!v&&uuid(v.draftId)&&count(v.version)&&v.version>0&&['draft','committed'].includes(v.state)
const date=(x:unknown)=>typeof x==='string'&&Number.isFinite(Date.parse(x))
const values=(v:RosterValues)=>!!v&&typeof v.name==='string'&&typeof v.email==='string'&&v.status==='active'&&date(v.joinedAt)&&date(v.endsAt)&&Date.parse(v.joinedAt)<Date.parse(v.endsAt)
const input=(v:ImportInput)=>!!v&&Array.isArray(v.header)&&v.header.every(h=>typeof h==='string')&&!!v.mapping&&Object.values(v.mapping).every(h=>typeof h==='string')&&Array.isArray(v.rows)&&v.rows.length<=50&&v.rows.every(r=>Array.isArray(r)&&r.every(c=>typeof c==='string'))
function receipt(v:RosterReceipt,term:string){return ref(v)&&v.state==='committed'&&v.termId===term&&count(v.created)&&count(v.unchanged)&&Array.isArray(v.items)&&v.items.length>0&&v.items.length<=50&&v.items.length===v.created+v.unchanged&&v.items.every(r=>!!r&&typeof r.sourceKey==='string'&&uuid(r.membershipId)&&uuid(r.memberId)&&typeof r.name==='string'&&['create','unchanged'].includes(r.action))&&new Set(v.items.map(r=>r.sourceKey)).size===v.items.length&&v.items.filter(r=>r.action==='create').length===v.created}
export function createRosterImportsApi(ready:ReturnType<typeof createSupabaseClient>):RosterImportsApi{
 async function rpc(name:'read_roster_import'|'save_roster_import'|'preview_roster_import'|'commit_roster_import',args:Record<string,unknown>){
  const c=await ready;if(!c)throw new ImportError('connection')
  let reply;try{reply=await c.rpc(name,args as never)}catch{throw new ImportError('connection')}
  if(!reply)throw new ImportError('connection')
  if(reply.error)throw new ImportError(reply.error.code==='42501'?'denied':reply.error.code==='40001'?'conflict':['22023','22007','22008','22P02','55000'].includes(reply.error.code)?'validation':'connection')
  return reply.data
 }
 return{
  async read(term,id){const v=await rpc('read_roster_import',{p_term_id:term,p_draft_id:id??null})as unknown as RosterRead
   if(!v||!Array.isArray(v.drafts)||v.drafts.length>20||!v.drafts.every(d=>ref(d)&&typeof d.listName==='string')||id&&v.draft?.draftId!==id||v.draft!==null&&(!ref(v.draft)||v.draft.termId!==term||typeof v.draft.listName!=='string'||!date(v.draft.joinedAt)||!date(v.draft.endsAt)||!input(v.draft.input)||v.draft.receipt!==null&&(!receipt(v.draft.receipt,term)||v.draft.receipt.draftId!==v.draft.draftId)))throw new ImportError('connection');return v},
  async save(term,list,joined,ends,data,id,version,key){const v=await rpc('save_roster_import',{p_term_id:term,p_list_name:list,p_joined_at:joined,p_ends_at:ends,p_input:data,p_draft_id:id,p_expected_version:version,p_request_id:key})as unknown as ImportRef;if(!ref(v)||v.state!=='draft'||id!==null&&v.draftId!==id)throw new ImportError('connection');return v},
  async preview(term,id,version){const v=await rpc('preview_roster_import',{p_draft_id:id,p_expected_version:version})as unknown as RosterPreview
   if(!v||v.termId!==term||v.draftId!==id||v.version!==version||typeof v.termLabel!=='string'||typeof v.listName!=='string'||!date(v.joinedAt)||!date(v.endsAt)||typeof v.valid!=='boolean'||!/^[a-f0-9]{64}$/.test(v.reviewHash)||!Array.isArray(v.rows)||v.rows.length<1||v.rows.length>50||!v.rows.every(r=>!!r&&count(r.record)&&r.record>=2&&typeof r.sourceKey==='string'&&['create','unchanged'].includes(r.operation)&&(r.targetId===null||uuid(r.targetId))&&(r.memberId===null||uuid(r.memberId))&&(r.expectedMembershipVersion===null||count(r.expectedMembershipVersion))&&(r.expectedMemberVersion===null||count(r.expectedMemberVersion))&&(r.before===null||values(r.before))&&values(r.after)&&Array.isArray(r.errors)&&r.errors.every(e=>typeof e==='string'))||v.valid&&v.rows.some(r=>r.errors.length))throw new ImportError('connection');return v},
  async commit(term,id,version,hash,reason,key){const v=await rpc('commit_roster_import',{p_draft_id:id,p_expected_version:version,p_review_hash:hash,p_reason:reason,p_request_id:key})as unknown as RosterReceipt;if(!receipt(v,term)||v.draftId!==id)throw new ImportError('connection');return v},
 }
}
