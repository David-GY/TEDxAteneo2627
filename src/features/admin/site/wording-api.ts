import type {createSupabaseClient} from '../../../lib/supabase'
import type {Json} from '../../../lib/database.types'
import {mapCommandError,type CommandResult} from '../../../lib/commands'
import {validSitePresentation,type SitePresentation} from './presentation'

export type SiteWordingDraft={draftId:string;version:number;baseVersion:number;definition:SitePresentation;rollbackVersionId:string|null;publishedVersionId:string|null}
export type SiteHistory={id:string;version:number;definition:SitePresentation;reason:string;supported:boolean}
export type SiteReview={valid:true;version:number;baseVersion:number;stale:boolean;previous:SitePresentation|null;proposed:SitePresentation;reviewHash:string;requiredActionsProtected:true;grantsAccess:false}
export type LogoChoice={assetId:string;approvalId:string;label:string;conditions:string;expiresAt:string}
export type SiteWordingConfiguration={version:number;definition:SitePresentation|null;draft:SiteWordingDraft|null;history?:SiteHistory[];nextBefore?:number|null}
export type SiteWordingSave={term:string;definition:SitePresentation;baseVersion:number;version:number;rollbackVersionId:string|null}
export type SitePublish={action:'publish';draftId:string;version:number;reviewHash:string;reason:string}
export interface SiteWordingApi{read(term:string,before?:number|null):Promise<SiteWordingConfiguration>;preview?(draft:string):Promise<SiteReview>;logos?(term:string):Promise<LogoChoice[]>;run(command:SiteWordingSave|SitePublish,key:string):Promise<CommandResult<{draftId:string;version:number}>>}
export class SiteWordingReadError extends Error{constructor(public denied:boolean){super('Site wording settings unavailable')}}
const uuid=(x:unknown):x is string=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x)
const version=(x:unknown):x is number=>Number.isSafeInteger(x)&&Number(x)>=0
export function createSiteWordingApi(ready:ReturnType<typeof createSupabaseClient>):SiteWordingApi{return{
 async read(term,before=null){
  const c=await ready;if(!c)throw new SiteWordingReadError(false)
  const{data,error}=await c.rpc('read_presentation_configuration',{p_term_id:term,p_kind:'site',p_target_kind:'term',p_target_id:term,p_before:before})
  if(error)throw new SiteWordingReadError(error.code==='42501')
  const v=data as unknown as {version:number;definition:SitePresentation|null;drafts:SiteWordingDraft[]}
  if(!v||!version(v.version)||(v.version===0?v.definition!==null:!validSitePresentation(v.definition))||!Array.isArray(v.drafts)||v.drafts.length>1||!v.drafts.every(d=>d&&uuid(d.draftId)&&version(d.version)&&d.version>0&&version(d.baseVersion)&&validSitePresentation(d.definition)&&(d.rollbackVersionId===null||uuid(d.rollbackVersionId))&&(d.publishedVersionId===null||uuid(d.publishedVersionId))))throw new SiteWordingReadError(false)
  const h=data as unknown as {history?:SiteHistory[];nextBefore?:number|null};if(h.history!==undefined&&(!Array.isArray(h.history)||h.history.length>50||!h.history.every(x=>x&&uuid(x.id)&&version(x.version)&&typeof x.reason==='string'))||h.nextBefore!=null&&!version(h.nextBefore))throw new SiteWordingReadError(false)
  return {version:v.version,definition:v.definition,draft:v.drafts[0]??null,history:h.history?.map(x=>({...x,supported:validSitePresentation(x.definition)}))??[],nextBefore:h.nextBefore??null}
 },
 async preview(draft){const c=await ready;if(!c)throw Error();const{data,error}=await c.rpc('preview_presentation_configuration',{p_draft_id:draft}),v=data as unknown as SiteReview;if(error)throw new SiteWordingReadError(error.code==='42501');if(!v||v.valid!==true||!version(v.version)||!version(v.baseVersion)||typeof v.stale!=='boolean'||!validSitePresentation(v.proposed)||v.previous!==null&&!validSitePresentation(v.previous)||!/^[a-f0-9]{64}$/.test(v.reviewHash)||v.requiredActionsProtected!==true||v.grantsAccess!==false)throw new SiteWordingReadError(false);return v},
 async logos(term){const c=await ready;if(!c)throw Error();const{data,error}=await c.rpc('read_site_logo_choices',{p_term_id:term});if(error)throw new SiteWordingReadError(error.code==='42501');const v=data as unknown as LogoChoice[];if(!Array.isArray(v)||v.length>100||!v.every(x=>x&&uuid(x.assetId)&&uuid(x.approvalId)&&typeof x.label==='string'&&typeof x.conditions==='string'&&Number.isFinite(Date.parse(x.expiresAt))))throw new SiteWordingReadError(false);return v},
 async run(command,key){
  if('definition'in command){if(!validSitePresentation(command.definition))return {ok:false,error:mapCommandError({code:'22023'})}}
  try{const c=await ready;if(!c)throw Error();const{data,error}=!('definition'in command)?await c.rpc('publish_presentation_configuration',{p_draft_id:command.draftId,p_expected_version:command.version,p_review_hash:command.reviewHash,p_reason:command.reason,p_request_id:key}):await c.rpc('save_presentation_draft',{p_term_id:command.term,p_kind:'site',p_target_kind:'term',p_target_id:command.term,p_definition:command.definition as unknown as Json,p_base_version:command.baseVersion,p_expected_version:command.version,p_request_id:key,p_rollback_version_id:command.rollbackVersionId})
   if(error)return {ok:false,error:mapCommandError(error)}
   const v=data as unknown as {draftId:string;version:number};if(!v||!uuid(v.draftId)||!version(v.version)||v.version<1)throw Error()
   return {ok:true,value:{draftId:v.draftId,version:v.version}}
  }catch{return {ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}}
 },
}}
