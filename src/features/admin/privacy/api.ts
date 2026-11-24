import type {createSupabaseClient} from '../../../lib/supabase'
import {mapCommandError,type CommandResult} from '../../../lib/commands'
import {createRetentionApi,type RetentionApi} from './retention'
import {createEmergencyApi,type EmergencyApi} from './emergency'
import {createFulfillmentApi,type FulfillmentApi} from './fulfillment'
import {createBackupHealthReader,type ReadBackupHealth} from '../health/api'
export const noticeFields=[['title','Notice title'],['controller','Responsible organization'],['purposes','Why information is used'],['requiredFields','Required information'],['optionalFields','Optional information and choices'],['recipients','Who may receive information'],['providers','Providers and hosting locations'],['retention','Approved retention information'],['rights','Rights and request handling'],['contactName','Approved privacy contact'],['contactRoute','Approved contact link'],['policyReference','Institutional review reference']]as const
export type Notice={version:1}&Record<typeof noticeFields[number][0],string>
export type PublishedNotice={revisionId:string;version:number;definition:Notice;approved:boolean;acknowledged:boolean}
export type PublicPrivacyNotice={notice:Omit<Notice,'policyReference'>;version:number;publishedAt:string;contactCheckedAt:string;validUntil:string}
export type RequestKind='access'|'correction'|'export'|'deletion'|'question'
export type RequestState='received'|'identity_check'|'in_review'|'referred'|'fulfilled'
export const kindNames:Record<RequestKind,string>={access:'Access to my information',correction:'Correction',export:'Export review',deletion:'Deletion review',question:'Privacy question'}
export const stateNames:Record<RequestState,string>={received:'Received for review',identity_check:'Identity check needed',in_review:'Under review',referred:'Referred to the approved channel',fulfilled:'Reviewed profile response released'}
export type RequestSummary={id:string;reference:string;kind:RequestKind;state:RequestState;version:number;createdAt:string;accountName?:string}
export type RequestDetail=RequestSummary&{message:string;canReview:boolean;replies:{version:number;state:RequestState;reply:string;at:string}[]}
export type PrivacyHub={notice:PublishedNotice|null;intakeAvailable:boolean;canAdmin:boolean;requests:RequestSummary[];page:number;hasMore:boolean}
export type NoticeDraft={draftId:string;version:number;baseVersion:number;definition:Notice;rollbackVersionId:string|null;publishedVersionId:string|null}
export type NoticeConfiguration={version:number;definition:Notice|null;drafts:NoticeDraft[];history:{id:string;version:number;definition:Notice;reason:string;supported:boolean}[];nextBefore:number|null}
export type NoticeReview={previous:Notice|null;proposed:Notice;reviewHash:string;stale:boolean}
export type PrivacyCommand={action:'create';term:string;kind:RequestKind;message:string}|{action:'ack';term:string;noticeId:string}|{action:'review';term:string;id:string;state:Exclude<RequestState,'received'|'fulfilled'>;reply:string;version:number}|{action:'saveNotice';term:string;definition:Notice;baseVersion:number;version:number;rollbackVersionId:string|null}|{action:'publishNotice';draftId:string;version:number;reviewHash:string;reason:string}
export interface PrivacyApi{backupHealth?:ReadBackupHealth;fulfillment?:FulfillmentApi;emergency?:EmergencyApi;publicNotice?(route?:string):Promise<PublicPrivacyNotice|null>;retention?:RetentionApi;read(term:string,page?:number):Promise<PrivacyHub>;detail(term:string,id:string):Promise<RequestDetail|null>;inbox(term:string,page?:number):Promise<{items:RequestSummary[];page:number;hasMore:boolean}>;notice(term:string,before?:number|null):Promise<NoticeConfiguration>;preview(id:string):Promise<NoticeReview>;run(command:PrivacyCommand,key:string):Promise<CommandResult<{version:number;id?:string;reference?:string}>>}
export class PrivacyReadError extends Error{constructor(public denied:boolean){super('Privacy information unavailable')}}
const uuid=(x:unknown):x is string=>typeof x==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(x)
const integer=(x:unknown)=>Number.isSafeInteger(x)&&Number(x)>=0
const text=(x:unknown,n=2000)=>typeof x==='string'&&x.trim().length>0&&x.length<=n&&!/[<>]/.test(x)&&!Array.from(x).some(c=>c.charCodeAt(0)<32||c.charCodeAt(0)===127)
const contact=(x:string)=>/^(https:\/\/[a-zA-Z0-9.-]+(\/[a-zA-Z0-9/._~-]*)?|mailto:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+[.][a-zA-Z]{2,})$/.test(x)
export function validNotice(x:unknown):x is Notice{if(!x||typeof x!=='object')return false;const n=x as Notice;return n.version===1&&Object.keys(n).length===13&&noticeFields.every(([k])=>text(n[k],k==='title'?200:2000))&&contact(n.contactRoute)}
function summary(r:RequestSummary){return r&&uuid(r.id)&&/^PRIV-\d+$/.test(r.reference)&&Object.hasOwn(kindNames,r.kind)&&Object.hasOwn(stateNames,r.state)&&integer(r.version)&&r.version>0&&Number.isFinite(Date.parse(r.createdAt))&&(r.accountName===undefined||typeof r.accountName==='string')}
export function createPrivacyApi(ready:ReturnType<typeof createSupabaseClient>):PrivacyApi{
 async function rpc(name:string,args:Record<string,unknown>){const c=await ready;if(!c)throw{code:'COMMAND_UNAVAILABLE'};const{data,error}=await c.rpc(name as never,args as never);if(error)throw error;return data as unknown}
 async function read<T>(name:string,args:Record<string,unknown>,valid:(x:T)=>boolean){try{const v=await rpc(name,args)as T;if(!valid(v))throw Error();return v}catch(e){throw new PrivacyReadError((e as{code?:string}).code==='42501')}}
 return{
 emergency:createEmergencyApi(ready),
 fulfillment:createFulfillmentApi(ready),
 backupHealth:createBackupHealthReader(ready),
 retention:createRetentionApi(ready),
 publicNotice:(route='workspace')=>read<PublicPrivacyNotice|null>('get_public_privacy_notice',{p_route:route},v=>v===null||!!v&&v.notice&&Object.keys(v.notice).length===12&&!Object.hasOwn(v.notice,'policyReference')&&validNotice({...v.notice,policyReference:'Public-audience projection'})&&integer(v.version)&&v.version>0&&Number.isFinite(Date.parse(v.publishedAt))&&Number.isFinite(Date.parse(v.contactCheckedAt))&&Date.parse(v.contactCheckedAt)<=Date.now()&&Date.parse(v.validUntil)>Date.now()),
 read:(term,page=1)=>read<PrivacyHub>('read_my_privacy',{p_term_id:term,p_page:page},v=>!!v&&(v.notice===null||uuid(v.notice.revisionId)&&integer(v.notice.version)&&validNotice(v.notice.definition)&&typeof v.notice.approved==='boolean'&&typeof v.notice.acknowledged==='boolean')&&typeof v.intakeAvailable==='boolean'&&typeof v.canAdmin==='boolean'&&Array.isArray(v.requests)&&v.requests.length<=20&&v.requests.every(summary)&&v.page===page&&typeof v.hasMore==='boolean'),
 detail:(term,id)=>read<RequestDetail|null>('read_privacy_request',{p_term_id:term,p_privacy_request_id:id},v=>v===null||summary(v)&&typeof v.message==='string'&&v.message.length<=2000&&typeof v.canReview==='boolean'&&Array.isArray(v.replies)&&v.replies.every(r=>r&&integer(r.version)&&Object.hasOwn(stateNames,r.state)&&typeof r.reply==='string'&&r.reply.length<=2000&&Number.isFinite(Date.parse(r.at)))),
 inbox:(term,page=1)=>read('read_privacy_inbox',{p_term_id:term,p_page:page},(v:{items:RequestSummary[];page:number;hasMore:boolean})=>!!v&&Array.isArray(v.items)&&v.items.length<=20&&v.items.every(summary)&&v.page===page&&typeof v.hasMore==='boolean'),
 notice:async(term,before=null)=>{const v=await read<NoticeConfiguration>('read_presentation_configuration',{p_term_id:term,p_kind:'privacy',p_target_kind:'term',p_target_id:term,p_before:before},v=>!!v&&integer(v.version)&&(v.definition===null||validNotice(v.definition))&&Array.isArray(v.drafts)&&v.drafts.length<=1&&v.drafts.every(d=>d&&uuid(d.draftId)&&integer(d.version)&&integer(d.baseVersion)&&validNotice(d.definition))&&Array.isArray(v.history)&&v.history.length<=50&&v.history.every(h=>h&&uuid(h.id)&&integer(h.version)&&typeof h.reason==='string')&&(v.nextBefore===null||integer(v.nextBefore)));return {...v,history:v.history.map(h=>({...h,supported:validNotice(h.definition)}))}},
 preview:id=>read<NoticeReview>('preview_presentation_configuration',{p_draft_id:id},v=>!!v&&(v.previous===null||validNotice(v.previous))&&validNotice(v.proposed)&&typeof v.stale==='boolean'&&/^[a-f0-9]{64}$/.test(v.reviewHash)),
 async run(c,key){try{let value:unknown
 if(c.action==='create')value=await rpc('create_privacy_request',{p_term_id:c.term,p_kind:c.kind,p_message:c.message,p_request_id:key})
 else if(c.action==='ack')value=await rpc('acknowledge_privacy_notice',{p_term_id:c.term,p_notice_version_id:c.noticeId,p_request_id:key})
 else if(c.action==='review')value=await rpc('review_privacy_request',{p_term_id:c.term,p_privacy_request_id:c.id,p_state:c.state,p_reply:c.reply,p_expected_version:c.version,p_request_id:key})
 else if(c.action==='saveNotice'){if(!validNotice(c.definition))throw{code:'22023'};value=await rpc('save_presentation_draft',{p_term_id:c.term,p_kind:'privacy',p_target_kind:'term',p_target_id:c.term,p_definition:c.definition,p_base_version:c.baseVersion,p_expected_version:c.version,p_request_id:key,p_rollback_version_id:c.rollbackVersionId})}
 else value=await rpc('publish_presentation_configuration',{p_draft_id:c.draftId,p_expected_version:c.version,p_review_hash:c.reviewHash,p_reason:c.reason,p_request_id:key})
 const v=value as{version:number;id?:string;reference?:string;draftId?:string;definitionVersionId?:string;acknowledged?:boolean};if(!v||!integer(v.version)||v.version<1||c.action==='create'&&(!uuid(v.id)||!/^PRIV-\d+$/.test(v.reference??''))||c.action==='saveNotice'&&!uuid(v.draftId)||c.action==='publishNotice'&&!uuid(v.definitionVersionId)||c.action==='ack'&&v.acknowledged!==true)throw{code:'COMMAND_UNAVAILABLE'};return{ok:true,value:v}
 }catch(e){const v=e as{message?:string};return{ok:false,error:v.message==='privacy_notice_approval_required'?{kind:'dependency_blocked',message:'Independent approval for this exact notice is missing or expired. Keep the private draft and obtain the approved institutional review.',retryable:false}:v.message==='privacy_intake_unconfigured'?{kind:'dependency_blocked',message:'An approved notice and current privacy custodian are required before intake. No request was sent.',retryable:false}:mapCommandError(e)}}},
 }
}
