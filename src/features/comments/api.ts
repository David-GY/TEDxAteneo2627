import type { createSupabaseClient } from '../../lib/supabase'
import { mapCommandError, type CommandResult } from '../../lib/commands'

export type CommentItem = { id:string;version:number;state:'draft'|'published'|'removed'|'redacted';author:string;createdAt:string;updatedAt:string;body:string|null;reason:string;mentions:string[];canEdit:boolean;canRedact:boolean;evidence:{revision:number;purpose:string;workVersion:number}[] }
export type CommentHistory = {revision:number;body:string|null;reason:string;state:string;recordedAt:string}
export type CommentPage = {items:CommentItem[];total:number;page:number;canComment:boolean}
export type Candidate = {id:string;name:string}
export type CommentInput = {workId:string;commentId?:string;version?:number;body:string;mentions:string[];draft:boolean;action:'edit'|'publish'|'remove'|'redact';reason:string}
export type CommentReceipt = {commentId:string;version:number}
export interface CommentsApi {
 read(id:string,page:number):Promise<CommentPage|null>
 history(id:string):Promise<CommentHistory[]>
 candidates(id:string,search:string):Promise<Candidate[]>
 execute(input:CommentInput,key:string):Promise<CommandResult<CommentReceipt>>
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const date = (v:unknown) => typeof v==='string' && Number.isFinite(Date.parse(v))
const version = (v:unknown) => Number.isSafeInteger(v) && (v as number)>0
export function createCommentsApi(ready:ReturnType<typeof createSupabaseClient>):CommentsApi {
 async function rpc(name:'read_comments'|'read_comment_history'|'mention_candidates',args:Record<string,unknown>) {
  const client=await ready;if(!client)throw new Error('Comments unavailable')
  const {data,error}=await client.rpc(name,args as never);if(error)throw new Error('Comments unavailable');return data
 }
 return {
  async read(id,page) {const r=await rpc('read_comments',{p_work_item_id:id,p_page:page}) as unknown as CommentPage|null;if(r===null)return null
   if(!r||!Array.isArray(r.items)||!Number.isSafeInteger(r.total)||r.total<0||r.page!==page||typeof r.canComment!=='boolean'||!r.items.every(c=>c&&uuid.test(c.id)&&version(c.version)&&['draft','published','removed','redacted'].includes(c.state)&&typeof c.author==='string'&&date(c.createdAt)&&date(c.updatedAt)&&(c.body===null||typeof c.body==='string')&&typeof c.reason==='string'&&typeof c.canEdit==='boolean'&&typeof c.canRedact==='boolean'&&Array.isArray(c.mentions)&&c.mentions.every(m=>uuid.test(m))&&Array.isArray(c.evidence)&&c.evidence.every(e=>version(e.revision)&&version(e.workVersion)&&['task','submission','decision'].includes(e.purpose))))throw new Error('Comments unavailable');return r},
  async history(id) {const r=await rpc('read_comment_history',{p_comment_id:id}) as unknown as CommentHistory[];if(!Array.isArray(r)||!r.every(h=>h&&version(h.revision)&&(h.body===null||typeof h.body==='string')&&typeof h.reason==='string'&&typeof h.state==='string'&&date(h.recordedAt)))throw new Error('History unavailable');return r},
  async candidates(id,search) {const r=await rpc('mention_candidates',{p_work_item_id:id,p_search:search}) as unknown as Candidate[];if(!Array.isArray(r)||!r.every(c=>c&&uuid.test(c.id)&&typeof c.name==='string'))throw new Error('Mentions unavailable');return r},
  async execute(input,key) {try{const client=await ready;if(!client)throw{code:'COMMAND_UNAVAILABLE'}
   const result=input.commentId?await client.rpc('revise_comment',{p_comment_id:input.commentId,p_body:input.body,p_mentions:input.mentions,p_action:input.action,p_reason:input.reason,p_expected_version:input.version!,p_request_id:key}):await client.rpc('add_comment',{p_work_item_id:input.workId,p_body:input.body,p_mentions:input.mentions,p_draft:input.draft,p_request_id:key})
   if(result.error)return{ok:false,error:mapCommandError(result.error)};const r=result.data as unknown as CommentReceipt;if(!r||!uuid.test(r.commentId)||!version(r.version))throw{code:'COMMAND_UNAVAILABLE'};return{ok:true,value:r}
  }catch(e){return{ok:false,error:mapCommandError(e)}}},
 }
}
