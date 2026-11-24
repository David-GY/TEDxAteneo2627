import {mapCommandError,type CommandResult} from '../../../lib/commands'
import type {createSupabaseClient} from '../../../lib/supabase'

export type ArchivedWork={id:string;title:string;reference:string|null;kind:'task'|'deliverable';summary:string;sourceTerm:string;owner:string|null;dueOn:string|null;dueAt:string|null;body?:string}
export type ArchivePage={items:ArchivedWork[];page:number;hasMore:boolean}
export type TurnoverState='preparing'|'frozen'|'exporting'|'verified'|'rehearsal_verified'|'complete'|'rehearsal_complete'
export type SuccessorTransfer={id:string;successor:string;name:string;term:string;reference:string;accepted:boolean;acceptedRun:string|null;work:ArchivedWork[]}
export type SuccessorCustody={id:string;recipient:string;name:string;category:string;version:number;reference:string;expiresAt:string;accepted:boolean;acceptedRun:string|null;qualified:boolean;records:{id:string;reference:string|null}[]}
export type TurnoverWorkspace={canManage:boolean;hasArchive:boolean;case:{id:string;version:number;state:TurnoverState;term:string;custodian:string;scope:'synthetic'|'operational'}|null;transfers:SuccessorTransfer[];custody:SuccessorCustody[];runs:{id:string;at:string;restored:boolean;failure:{phase:string;reason:string}|null}[];
  approvals:{id:string;reference:string;scope:string}[];units:{id:string;name:string;owner:string|null;checked:boolean}[];
  work:{id:string;version:number;title:string;reference:string|null;state:string;classification:string;resolution:string|null;recordedVersion:number|null;owner:string|null;successor:string|null;transferable:boolean}[];
  people:{id:string;name:string}[];successors:{id:string;name:string;term:string;termId:string}[];roles:{id:string;name:string;version:number}[];grants:{id:string;name:string;version:number}[];
  categories:{category:string;disposition:string;rows:number;reviewOn:string}[]}
export type TurnoverAcceptance={kind:'acceptRecords'|'acceptCustody';term:string;id:string;run:string;reference:string}
export type TurnoverCommand=TurnoverAcceptance|{kind:'prepare';term:string;approval:string}|{kind:'update';caseId:string;version:number;action:'unit'|'obligation'|'transfer'|'correction';values:Record<string,string|number|null|string[]>}|
  {kind:'freeze'|'archive';caseId:string;version:number}|{kind:'verify'|'complete';caseId:string;version:number;run:string;reference:string}|
  {kind:'nominate';caseId:string;version:number;recipient:string;category:string;work:string[];authority:string;expiresAt:string;reference:string}|
  {kind:'custodyAction';term:string;id:string;version:number;action:'hold'|'release_hold'|'correction';values:Record<string,string|number>;reference:string}
export type TurnoverSetup={authorities:{id:string;recipient:string;name:string;category:string;expiresAt:string}[];privateRoots:{id:string;reference:string;category:string}[]}
export type ArchivedCustody={id:string;version:number;category:string;workIds:string[];expiresAt:string;holds:{id:string;objectId:string;reviewAt:string;overdue:boolean;version:number}[]}
export type TurnoverReceipt={id:string;version:number}
const obj=(v:unknown):Record<string,unknown>=>{if(!v||typeof v!=='object'||Array.isArray(v))throw Error('Invalid archive response');return v as Record<string,unknown>}
const str=(v:unknown):string=>{if(typeof v!=='string')throw Error('Invalid archive response');return v}
const nullable=(v:unknown)=>v===null?null:str(v)
const uuid=(v:unknown):string=>{const s=str(v);if(!/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(s))throw Error('Invalid archive response');return s}
const idOrNull=(v:unknown)=>v===null?null:uuid(v)
const num=(v:unknown):number=>{if(typeof v!=='number'||!Number.isSafeInteger(v)||v<1)throw Error('Invalid archive response');return v}
const bool=(v:unknown):boolean=>{if(typeof v!=='boolean')throw Error('Invalid archive response');return v}
const list=<T>(v:unknown,parse:(v:unknown)=>T):T[]=>{if(!Array.isArray(v))throw Error('Invalid archive response');return v.map(parse)}
const time=(v:unknown)=>{const s=str(v);if(!Number.isFinite(Date.parse(s)))throw Error('Invalid archive response');return s}
export function parseArchivedWork(value:unknown,detail=false):ArchivedWork{
  const w=obj(value),kind=str(w.kind)
  if(kind!=='task'&&kind!=='deliverable')throw Error('Invalid archive kind')
  return {id:uuid(w.id),title:str(w.title),reference:nullable(w.reference),kind,summary:str(w.summary),sourceTerm:str(w.sourceTerm),owner:nullable(w.owner),
    dueOn:w.dueOn===null?null:time(w.dueOn),dueAt:w.dueAt===null?null:time(w.dueAt),...(detail?{body:str(w.body)}:{})}
}
export function parseTurnover(value:unknown):TurnoverWorkspace{
  const w=obj(value),c=w.case===null?null:obj(w.case)
  const states:TurnoverState[]=['preparing','frozen','exporting','verified','rehearsal_verified','complete','rehearsal_complete']
  if(c&&(!states.includes(c.state as TurnoverState)||!['synthetic','operational'].includes(str(c.scope))))throw Error('Invalid turnover state')
  return {canManage:bool(w.canManage),hasArchive:bool(w.hasArchive),case:c?{id:uuid(c.id),version:num(c.version),state:c.state as TurnoverState,term:str(c.term),custodian:str(c.custodian),scope:c.scope as 'synthetic'|'operational'}:null,
    transfers:list(w.transfers,v=>{const t=obj(v);return {id:uuid(t.id),successor:uuid(t.successor),name:str(t.name),term:str(t.term),reference:str(t.reference),accepted:bool(t.accepted),acceptedRun:idOrNull(t.acceptedRun),work:list(t.work,v=>parseArchivedWork(v,true))}}),
    custody:list(w.custody,v=>{const n=obj(v);return {id:uuid(n.id),recipient:uuid(n.recipient),name:str(n.name),category:str(n.category),version:num(n.version),reference:str(n.reference),expiresAt:time(n.expiresAt),accepted:bool(n.accepted),acceptedRun:idOrNull(n.acceptedRun),qualified:bool(n.qualified),records:list(n.records,v=>{const r=obj(v);return {id:uuid(r.id),reference:nullable(r.reference)}})}}),
    runs:list(w.runs,v=>{const r=obj(v),f=r.failure===null?null:obj(r.failure);return {id:uuid(r.id),at:time(r.at),restored:bool(r.restored),failure:f?{phase:str(f.phase),reason:str(f.reason)}:null}}),
    approvals:list(w.approvals,v=>{const r=obj(v);return {id:uuid(r.id),reference:str(r.reference),scope:str(r.scope)}}),
    units:list(w.units,v=>{const r=obj(v);return {id:uuid(r.id),name:str(r.name),owner:idOrNull(r.owner),checked:bool(r.checked)}}),
    work:list(w.work,v=>{const r=obj(v);return {id:uuid(r.id),version:num(r.version),title:str(r.title),reference:nullable(r.reference),state:str(r.state),classification:str(r.classification),resolution:nullable(r.resolution),recordedVersion:r.recordedVersion===null?null:num(r.recordedVersion),owner:idOrNull(r.owner),successor:idOrNull(r.successor),transferable:bool(r.transferable)}}),
    people:list(w.people,v=>{const r=obj(v);return {id:uuid(r.id),name:str(r.name)}}),
    successors:list(w.successors,v=>{const r=obj(v);return {id:uuid(r.id),name:str(r.name),term:str(r.term),termId:uuid(r.termId)}}),
    roles:list(w.roles,v=>{const r=obj(v);return {id:uuid(r.id),name:str(r.name),version:num(r.version)}}),
    grants:list(w.grants,v=>{const r=obj(v);return {id:uuid(r.id),name:str(r.name),version:num(r.version)}}),
    categories:list(w.categories,v=>{const r=obj(v);if(typeof r.rows!=='number'||!Number.isSafeInteger(r.rows)||r.rows<0)throw Error();return {category:str(r.category),disposition:str(r.disposition),rows:r.rows,reviewOn:str(r.reviewOn)}})}
}
export function createTurnoverApi(ready:ReturnType<typeof createSupabaseClient>){
  async function client(){const c=await ready;if(!c)throw Error('Archive connection unavailable');return c}
  return {
    async setup(term:string):Promise<TurnoverSetup>{
      const {data,error}=await(await client()).rpc('read_turnover_setup',{p_term_id:term});if(error)throw Error('Custody setup unavailable')
      const s=obj(data);return {authorities:list(s.authorities,v=>{const a=obj(v);return {id:uuid(a.id),recipient:uuid(a.recipient),name:str(a.name),category:str(a.category),expiresAt:time(a.expiresAt)}}),
        privateRoots:list(s.privateRoots,v=>{const r=obj(v);return {id:uuid(r.id),reference:str(r.reference),category:str(r.category)}})}
    },
    async custody(term:string,id:string):Promise<ArchivedCustody>{
      const {data,error}=await(await client()).rpc('read_archived_custody',{p_context_term:term,p_custody_id:id});if(error)throw Error('Archived custody unavailable')
      const n=obj(data);if(uuid(n.id)!==id)throw Error();return {id,version:num(n.version),category:str(n.category),workIds:list(n.workIds,uuid),expiresAt:time(n.expiresAt),
        holds:list(n.holds,v=>{const h=obj(v);return {id:uuid(h.id),objectId:uuid(h.objectId),reviewAt:time(h.reviewAt),overdue:bool(h.overdue),version:num(h.version)}})}
    },
    async workspace(term:string,caseId?:string):Promise<TurnoverWorkspace>{
      const {data,error}=await(await client()).rpc('read_turnover',{p_term_id:term,p_case_id:caseId??null})
      if(error)throw Error('Handover access could not be checked')
      return parseTurnover(data)
    },
    async archive(term:string,page=1):Promise<ArchivePage>{
      const {data,error}=await(await client()).rpc('read_archived_work_page',{p_term_id:term,p_page:page})
      if(error)throw Error('Archive access could not be checked')
      const r=obj(data),items=list(r.items,v=>parseArchivedWork(v))
      if(num(r.page)!==page||items.length>50)throw Error('Invalid archive page')
      return {items,page,hasMore:bool(r.hasMore)}
    },
    async record(term:string,id:string):Promise<ArchivedWork|null>{
      const {data,error}=await(await client()).rpc('read_archived_work',{p_term_id:term,p_work_id:id})
      if(error)throw Error('Archived record could not be checked')
      const detail=obj(data).detail;if(detail===null)return null
      const record=parseArchivedWork(detail,true);if(record.id!==id)throw Error('Invalid archive record');return record
    },
    async run(q:TurnoverCommand,key:string):Promise<CommandResult<TurnoverReceipt>>{
      try{
        const c=await client()
        const {data,error}=q.kind==='acceptRecords'?await c.rpc('accept_turnover',{p_context_term:q.term,p_run_id:q.run,p_reference:q.reference,p_key:key,p_transfer_id:q.id}):
          q.kind==='acceptCustody'?await c.rpc('accept_turnover_custody',{p_context_term:q.term,p_run_id:q.run,p_reference:q.reference,p_key:key,p_custody_id:q.id}):
          q.kind==='prepare'?await c.rpc('prepare_turnover',{p_term_id:q.term,p_approval_id:q.approval,p_key:key}):
          q.kind==='update'?await c.rpc('update_turnover',{p_case_id:q.caseId,p_expected_version:q.version,p_action:q.action,p_values:q.values,p_key:key}):
          q.kind==='nominate'?await c.rpc('propose_turnover_custody',{p_case_id:q.caseId,p_expected_version:q.version,p_recipient:q.recipient,p_category:q.category,p_work_ids:q.work,p_authority:q.authority,p_expires_at:q.expiresAt,p_reference:q.reference,p_key:key}):
          q.kind==='freeze'?await c.rpc('freeze_term',{p_case_id:q.caseId,p_expected_version:q.version,p_key:key}):
          q.kind==='archive'?await c.rpc('run_archive',{p_case_id:q.caseId,p_expected_version:q.version,p_key:key}):
          q.kind==='verify'?await c.rpc('verify_turnover_archive',{p_case_id:q.caseId,p_run_id:q.run,p_expected_version:q.version,p_key:key}):
          q.kind==='complete'?await c.rpc('complete_turnover',{p_case_id:q.caseId,p_run_id:q.run,p_expected_version:q.version,p_reference:q.reference,p_key:key}):
          q.kind==='custodyAction'?await c.rpc('act_archived_custody',{p_context_term:q.term,p_custody_id:q.id,p_expected_version:q.version,p_action:q.action,p_values:q.values,p_reference:q.reference,p_key:key}):await Promise.reject(Error('Unknown turnover command'))
        if(error){const mapped=mapCommandError(error),message=turnoverErrors[error.message];return {ok:false,error:message?{...mapped,message}:mapped}}
        const r=obj(data),id=uuid(r.id)
        if((q.kind==='acceptRecords'||q.kind==='acceptCustody')&&id!==q.id)throw Error('Invalid acceptance receipt')
        return {ok:true,value:{id,version:num(r.version)}}
      }catch{return {ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}}
    },
  }
}
export type TurnoverApi=ReturnType<typeof createTurnoverApi>
const turnoverErrors:Record<string,string>={
  command_turnover_archive_incomplete:'The archive has not passed all file and restore checks. Ask the archive operator to finish the named generation, then verify again.',
  command_turnover_operational_gate:'Operational closure is awaiting approved recovery and independent custody evidence. Synthetic rehearsal is available only under its own authorization.',
  command_turnover_checklist_incomplete:'Review every unit and unresolved item. Each needs a current responsible person and recorded outcome before freeze.',
  command_turnover_carry_acceptance_required:'A carried item or private custody scope still needs the qualified successor’s acceptance of this archive.',
  command_turnover_acceptance_required:'Successor acceptance is incomplete. Ask each named recipient to review this archive before completion.',
  command_turnover_source_changed:'The records or holds changed. Prepare and verify a current archive generation before continuing.',
  command_turnover_scope_overlap:'An outgoing scope is already selected for another recipient. Review the transfer plan.',
  command_turnover_policy_required:'An independently approved retention policy covering these records is required. Ask the privacy custodian to finish policy review.',
}
