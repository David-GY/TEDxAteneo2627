import {mapCommandError,type CommandResult} from '../../lib/commands'
import type {createSupabaseClient} from '../../lib/supabase'
import {validDate} from '../forms/validation'

export type ItemKind='returnable'|'consumable'
export type Condition='usable'|'worn'
export type NamedWork={id:string;label:string;kind:'task'|'deliverable'}
export type StockItem={
  id:string;name:string;location:string;kind:ItemKind;version:number;available:number
  custodian:string|null;custodianId:string|null;canReserve:boolean;canReassign:boolean;canStartFinance:boolean;needsCustodian:boolean
}
export type InventoryHistory={
  version:number;action:'reserve'|'issue'|'consume'|'return'|'damage'|'loss'|'cancel'
  quantity:number;condition:Condition|'damaged'|'missing'|null;note:string|null;at:string;evidence:boolean
  incidentId:string|null;financeStarted:boolean;financeRequestId:string|null
}
export type Loan={
  id:string;itemId:string;item:string;kind:ItemKind;location:string;reference:string;version:number
  quantity:number;startsOn:string;dueOn:string;state:'reserved'|'issued'|'partial'|'complete'|'cancelled'
  outstanding:number;returned:number;damaged:number;lost:number;consumed:number
  borrower:string;borrowerActive:boolean;custodian:boolean;canStartFinance:boolean
  relatedWork:NamedWork|null;history:InventoryHistory[]
}
export type InventoryWorkspace={
  termLabel:string;steward:boolean;editable:boolean;actorId:string;items:StockItem[];loans:Loan[]
  custodians:{id:string;name:string}[];work:NamedWork[];moreItems:boolean;moreLoans:boolean
}
export type InventoryEvidence={id:string;work:string;workId:string;kind:NamedWork['kind'];files:string[];at:string}
type BookingShortcut={id:string;item:string;reference:string}
export type InventoryEntry={enabled:boolean;checkout:BookingShortcut|null;dueReturn:BookingShortcut|null}
export type Movement='issue'|'return'|'damage'|'loss'|'cancel'
export type InventoryCommand={term:string}&(
  {kind:'register';name:string;location:string;itemKind:ItemKind;quantity:number;condition:Condition;custodian:string}|
  {kind:'reserve';item:string;version:number;quantity:number;startsOn:string;dueOn:string;work:string|null}|
  {kind:'movement';loan:string;version:number;action:Movement;quantity:number;condition:Condition|null;note:string|null;evidence:string|null}|
  {kind:'reassign';item:string;version:number;custodian:string;note:string}|
  {kind:'finance';item:string;version:number;incident:string|null})
export type InventoryReceipt={version:number}&({itemId:string}|{loanId:string;reference:string}|{financeRequestId:string})

const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v)
const optionalId=(v:unknown)=>v===null||uuid(v)
const text=(v:unknown):v is string=>typeof v==='string'&&v.trim().length>0
const optionalText=(v:unknown)=>v===null||text(v)
const int=(v:number,min=0)=>Number.isSafeInteger(v)&&v>=min
const flags=(...v:unknown[])=>v.every(x=>typeof x==='boolean')
const kind=(v:ItemKind)=>v==='returnable'||v==='consumable'
const work=(v:NamedWork)=>v&&uuid(v.id)&&text(v.label)&&['task','deliverable'].includes(v.kind)
const reference=(v:unknown)=>typeof v==='string'&&/^BOR-[0-9]{3,19}$/.test(v)
const shortcut=(v:BookingShortcut|null)=>v===null||v&&uuid(v.id)&&text(v.item)&&reference(v.reference)
const timestamp=(v:unknown)=>typeof v==='string'&&Number.isFinite(Date.parse(v))
const itemShape=(i:StockItem)=>i&&uuid(i.id)&&text(i.name)&&text(i.location)&&kind(i.kind)&&int(i.version,1)
  &&int(i.available)&&optionalText(i.custodian)&&optionalId(i.custodianId)
  &&flags(i.canReserve,i.canReassign,i.canStartFinance,i.needsCustodian)
const history=(h:InventoryHistory)=>h&&int(h.version,1)&&int(h.quantity,1)&&timestamp(h.at)
  &&['reserve','issue','consume','return','damage','loss','cancel'].includes(h.action)
  &&(h.condition===null||['usable','worn','damaged','missing'].includes(h.condition))&&optionalText(h.note)
  &&optionalId(h.incidentId)&&optionalId(h.financeRequestId)&&flags(h.evidence,h.financeStarted)
const loanShape=(b:Loan)=>b&&uuid(b.id)&&uuid(b.itemId)&&text(b.item)&&text(b.location)&&kind(b.kind)&&reference(b.reference)
  &&int(b.version,1)&&int(b.quantity,1)&&validDate(b.startsOn)&&validDate(b.dueOn)&&b.startsOn<=b.dueOn
  &&['reserved','issued','partial','complete','cancelled'].includes(b.state)
  &&[b.outstanding,b.returned,b.damaged,b.lost,b.consumed].every(n=>int(n)&&n<=b.quantity)
  &&text(b.borrower)&&flags(b.borrowerActive,b.custodian,b.canStartFinance)&&(b.relatedWork===null||work(b.relatedWork))
  &&Array.isArray(b.history)&&b.history.length<=100&&b.history.every(history)

const inventoryProblems:Record<string,string>={
  command_inventory_unavailable:'Inventory borrowing is unavailable for the current term.',
  command_inventory_shortage:'There is less stock available than you entered. Your entries are kept. Check the current quantity.',
  command_inventory_custodian_unavailable:'A current custodian is required. Keep your entries while the inventory steward assigns someone.',
  command_inventory_state_changed:'This booking changed. Review its current quantities and condition before continuing.',
  command_inventory_pickup_unavailable:'Check the pickup date and the borrower’s current workspace access.',
  command_inventory_finance_unavailable:'The approved FIN request path is unavailable. Contact the finance service.',
  command_inventory_finance_exists:'A FIN request has already been started for this incident. Refresh its history.',
}

export function createInventoryApi(ready:ReturnType<typeof createSupabaseClient>){
  async function client(){
    const c=await ready
    if(!c)throw Error('Inventory connection unavailable')
    return c
  }
  return {
    async entry(term:string):Promise<InventoryEntry>{
      const {data,error}=await(await client()).rpc('read_inventory_entry',{p_term_id:term})
      const v=data as InventoryEntry|null
      if(error||!v||!flags(v.enabled)||!shortcut(v.checkout)||!shortcut(v.dueReturn))throw Error('Inventory access could not be checked')
      return v
    },
    async read(term:string,loan:string|null,itemPage=1,loanPage=1,query=''):Promise<InventoryWorkspace|null>{
      const {data,error}=await(await client()).rpc('read_inventory_workspace',{
        p_term_id:term,p_loan_id:loan,p_item_page:itemPage,p_loan_page:loanPage,p_item_query:query||null,
      })
      if(!error&&data===null)return null
      const w=data as InventoryWorkspace|null
      if(error||!w||!text(w.termLabel)||!uuid(w.actorId)||!flags(w.steward,w.editable,w.moreItems,w.moreLoans)
        ||!Array.isArray(w.items)||!w.items.every(itemShape)||!Array.isArray(w.loans)||!w.loans.every(loanShape)
        ||!Array.isArray(w.custodians)||!w.custodians.every(x=>x&&uuid(x.id)&&text(x.name))
        ||!Array.isArray(w.work)||!w.work.every(work)||loan&&(w.loans.length!==1||w.loans[0]?.id!==loan))
        throw Error('Inventory could not be checked')
      return w
    },
    async evidence(term:string,loan:string):Promise<InventoryEvidence[]|null>{
      const {data,error}=await(await client()).rpc('read_inventory_evidence',{p_term_id:term,p_loan_id:loan})
      if(!error&&data===null)return null
      const entries=data as InventoryEvidence[]|null
      if(error||!Array.isArray(entries)||!entries.every(e=>e&&uuid(e.id)&&uuid(e.workId)&&text(e.work)
        &&['task','deliverable'].includes(e.kind)&&timestamp(e.at)&&Array.isArray(e.files)&&e.files.length>0&&e.files.every(text)))
        throw Error('Finalized evidence could not be checked')
      return entries
    },
    async run(command:InventoryCommand,key:string):Promise<CommandResult<InventoryReceipt>>{
      try{
        const c=await client(),base={p_term_id:command.term,p_key:key}
        const result=command.kind==='register'?await c.rpc('register_inventory_item',{
          ...base,p_label:command.name,p_location:command.location,p_kind:command.itemKind,p_opening_quantity:command.quantity,
          p_custodian_id:command.custodian,p_condition:command.condition,
        }):command.kind==='reserve'?await c.rpc('reserve_inventory',{
          ...base,p_item_id:command.item,p_expected_version:command.version,p_quantity:command.quantity,
          p_starts_on:command.startsOn,p_due_on:command.dueOn,p_related_work_id:command.work,
        }):command.kind==='movement'?await c.rpc('record_inventory_movement',{
          ...base,p_loan_id:command.loan,p_expected_version:command.version,p_action:command.action,p_quantity:command.quantity,
          p_condition:command.condition,p_note:command.note,p_evidence_manifest_id:command.evidence,
        }):command.kind==='reassign'?await c.rpc('reassign_inventory_custodian',{
          ...base,p_item_id:command.item,p_expected_version:command.version,p_custodian_id:command.custodian,p_reason:command.note,
        }):await c.rpc('start_inventory_finance',{
          ...base,p_item_id:command.item,p_expected_version:command.version,p_incident_id:command.incident,
        })
        if(result.error){
          const mapped=mapCommandError(result.error),message=inventoryProblems[result.error.message]
          return {ok:false,error:typeof message==='string'?{...mapped,message}:mapped}
        }
        const v=result.data as InventoryReceipt|null
        if(!v||!int(v.version,1))throw Error()
        if(command.kind==='reserve'&&'loanId'in v&&uuid(v.loanId)&&reference(v.reference)&&v.version===1
          ||command.kind==='movement'&&'loanId'in v&&v.loanId===command.loan&&reference(v.reference)&&v.version===command.version+1
          ||command.kind==='register'&&'itemId'in v&&uuid(v.itemId)&&v.version===1
          ||command.kind==='reassign'&&'itemId'in v&&v.itemId===command.item&&v.version===command.version+1
          ||command.kind==='finance'&&'financeRequestId'in v&&uuid(v.financeRequestId)&&v.version===1)
          return {ok:true,value:v}
        throw Error()
      }catch{return {ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}}
    },
  }
}
export type InventoryApi=ReturnType<typeof createInventoryApi>
