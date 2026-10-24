import type {createSupabaseClient} from '../../lib/supabase'
import {mapCommandError,type CommandResult} from '../../lib/commands'

export type EffortBand='small'|'medium'|'large'
export type AgreementState='proposed'|'countered'|'accepted'|'declined'
export type SynergyTerms={output:string;criteria:string;effort:EffortBand;dueOn:string;reason:string;sourceManifestIds?:string[]}
export type CounterTerms=Omit<SynergyTerms,'sourceManifestIds'>
export type ProposeSynergy={parentId:string;receiverUnitId:string;terms:SynergyTerms;expectedParentVersion:number;requestId:string;amendment?:{agreementId:string;expectedVersion:number}}
type ResponseBase={agreementId:string;expectedVersion:number;expectedRevision:number;reason:string;requestId:string}
export type RespondToSynergy=ResponseBase&({action:'accept';ownerId:string|null;terms?:never}|{action:'decline';ownerId?:never;terms?:never}|{action:'counter';ownerId:string;terms:CounterTerms})
export type AgreementReceipt={agreementId:string;version:number;revision:number;state:AgreementState;contributionId?:string|null}
type TermsView={output:string;criteria:string;effort:EffortBand;dueOn:string;ownerId:string|null}
export type AgreementView={id:string;version:number;revision:number;activeRevision:number|null;state:AgreementState;requesterUnitId:string;receiverUnitId:string;requesterName:string;parentId:string|null;terms:TermsView;sources:string[];contributionId:string|null;
 revisions:(TermsView&{revision:number;side:'requester'|'receiver';reason:string;recordedAt:string})[];
 confirmations:{revision:number;side:'requester'|'receiver';decision:'propose'|'counter'|'accept'|'decline';memberId:string;ownerId:string|null;reason:string;recordedAt:string}[]}
export type ContributionView={id:string;agreementId:string;revision:number;ownerId:string;ownerName:string;requesterUnitId:string;receiverUnitId:string;parentId:string|null;output:string;criteria:string;effort:EffortBand;dueOn:string;task:{id:string;version:number;state:string;assigneeId:string|null}}
export interface SynergiesApi{propose(input:ProposeSynergy):Promise<CommandResult<AgreementReceipt>>;respond(input:RespondToSynergy):Promise<CommandResult<AgreementReceipt>>;read(agreementId:string):Promise<AgreementView|null>;contribution(workId:string):Promise<ContributionView|null>}
const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)
const nullableUuid=(v:unknown)=>v===null||uuid(v)
const positive=(v:unknown)=>Number.isSafeInteger(v)&&(v as number)>0
const date=(v:unknown)=>typeof v==='string'&&Number.isFinite(Date.parse(v))
const state=(v:unknown)=>['proposed','countered','accepted','declined'].includes(String(v))
function terms(v:unknown):v is TermsView{if(!v||typeof v!=='object')return false;const t=v as TermsView;return typeof t.output==='string'&&typeof t.criteria==='string'&&['small','medium','large'].includes(t.effort)&&date(t.dueOn)&&nullableUuid(t.ownerId)}
function receipt(v:unknown):v is AgreementReceipt{if(!v||typeof v!=='object')return false;const r=v as AgreementReceipt;return uuid(r.agreementId)&&positive(r.version)&&positive(r.revision)&&state(r.state)&&(r.contributionId===undefined||nullableUuid(r.contributionId))&&(r.state!=='accepted'||uuid(r.contributionId))}
export function createSynergiesApi(ready:ReturnType<typeof createSupabaseClient>):SynergiesApi{
 async function client(){const c=await ready;if(!c)throw{code:'COMMAND_UNAVAILABLE'};return c}
 async function command(run:()=>PromiseLike<{data:unknown;error:unknown}>):Promise<CommandResult<AgreementReceipt>>{try{const{data,error}=await run();if(error)return{ok:false,error:mapCommandError(error)};if(!receipt(data))throw{code:'COMMAND_UNAVAILABLE'};return{ok:true,value:data}}catch(e){return{ok:false,error:mapCommandError(e)}}}
 return{
 propose(input){return command(async()=> (await client()).rpc('propose_synergy',{p_parent_id:input.parentId,p_receiver_unit_id:input.receiverUnitId,p_terms:input.terms,p_expected_parent_version:input.expectedParentVersion,p_request_id:input.requestId,p_agreement_id:input.amendment?.agreementId??null,p_expected_agreement_version:input.amendment?.expectedVersion??null}))},
 respond(input){return command(async()=> (await client()).rpc('respond_to_synergy',{p_agreement_id:input.agreementId,p_action:input.action,p_expected_version:input.expectedVersion,p_expected_revision:input.expectedRevision,p_owner_id:(input.ownerId??null)!,p_terms:input.terms??null,p_reason:input.reason,p_request_id:input.requestId}))},
 async read(id){if(!uuid(id))return null;try{const{data,error}=await(await client()).rpc('read_synergy',{p_agreement_id:id});if(error)throw error;if(data===null)return null;const r=data as unknown as AgreementView;if(!r||!uuid(r.id)||!positive(r.version)||!positive(r.revision)||(r.activeRevision!==null&&!positive(r.activeRevision))||!state(r.state)||!uuid(r.requesterUnitId)||!uuid(r.receiverUnitId)||typeof r.requesterName!=='string'||!nullableUuid(r.parentId)||!nullableUuid(r.contributionId)||!terms(r.terms)||!Array.isArray(r.sources)||!r.sources.every(uuid)||!Array.isArray(r.revisions)||!r.revisions.every(h=>terms(h)&&positive(h.revision)&&['requester','receiver'].includes(h.side)&&typeof h.reason==='string'&&date(h.recordedAt))||!Array.isArray(r.confirmations)||!r.confirmations.every(h=>h&&positive(h.revision)&&uuid(h.memberId)&&nullableUuid(h.ownerId)&&['requester','receiver'].includes(h.side)&&['propose','counter','accept','decline'].includes(h.decision)&&typeof h.reason==='string'&&date(h.recordedAt)))throw new Error();return r}catch{throw new Error('Agreement could not load. Check access or connection and retry.')}},
 async contribution(id){if(!uuid(id))return null;try{const{data,error}=await(await client()).rpc('read_contribution',{p_work_item_id:id});if(error)throw error;if(data===null)return null;const c=data as unknown as ContributionView;if(!c||!uuid(c.id)||!uuid(c.agreementId)||!positive(c.revision)||!uuid(c.ownerId)||typeof c.ownerName!=='string'||!uuid(c.requesterUnitId)||!uuid(c.receiverUnitId)||!nullableUuid(c.parentId)||!terms({...c,ownerId:c.ownerId})||!c.task||c.task.id!==c.id||!positive(c.task.version)||c.task.assigneeId!==c.ownerId||!['todo','in_progress','blocked','ready_for_review','done','cancelled'].includes(c.task.state))throw new Error();return c}catch{throw new Error('Contribution could not load. Check access or connection and retry.')}},
 }
}
