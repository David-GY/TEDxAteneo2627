import { mapCommandError,type CommandResult } from '../../lib/commands'
import type { createSupabaseClient } from '../../lib/supabase'
import type { WorkReferenceValue } from '../work-references/api'

export type Room = {
  id:string;name:string;capacity:number;accessible:boolean;equipment:string[];setupMinutes:number;cleanupMinutes:number
}
export type RoomCatalogue = {rooms:Room[];policyVersion:number|null;evidenceMode:'required'|'official_not_required'|null}
export type Booking = {
  requestId:string;reference:WorkReferenceValue;version:number;sourceRevision:number;requestChanged:boolean
  room:Pick<Room,'id'|'name'>;startsAt:string;endsAt:string;setupMinutes:number;cleanupMinutes:number
  purpose:string;attendees:number;accessible:boolean;equipment:string[]
  state:'requested'|'held'|'confirmed'|'cancelled';holdUntil:string|null;holdExpired:boolean
  evidence:{kind:'school_record'|'official_not_required';policyVersion:number;version:number}|null
}
export type Slot = {room:string;startsAt:string;endsAt:string}
export type AvailableRoom = Room & {available:boolean|null}
export type NamedSlot = Pick<Slot,'startsAt'|'endsAt'>&{room:Pick<Room,'id'|'name'>}
export type RoomAlternative = NamedSlot&{available:boolean}
export type BookingWorkspace = {
  booking:Booking|null;rooms:AvailableRoom[];availabilityWindow:Pick<Slot,'startsAt'|'endsAt'>|null;reference:WorkReferenceValue
  requestTitle:string;service:string|null;requester:boolean;canRequest:boolean;canDecide:boolean;canCancel:boolean
  policyVersion:number|null;evidenceMode:RoomCatalogue['evidenceMode'];maxHoldMinutes:number|null
  officialReference:string|null;evidence:{id:string;createdAt:string;names:string[]}[]
  schoolFiles:string[]
  alternative:RoomAlternative|null;offerVersion:number
  desiredSlot:NamedSlot|null;contact:{id:string;name:string}|null
}
type Command = {term:string;request:string;version:number;reason:string}
export type BookingCommand = Command & (
  {kind:'request';slot:Slot;purpose:string;attendees:number;accessible:boolean;equipment:string[]}|
  {kind:'hold';minutes:number}|{kind:'cancel'}|
  {kind:'offer';slot:Slot;policyVersion:number;offerVersion:number}|
  {kind:'confirm';slot:Slot;policyVersion:number;manifest:string|null;officialReference:string|null}
)
export type BookingOutcome =
  {outcome:'saved';booking:Booking}|
  {outcome:'offered';offerVersion:number}|
  {outcome:'blocked';reason:'room_unsuitable';booking:Booking|null}|
  {outcome:'conflict';reason:'slot_unavailable';booking:Booking|null}
export const bookingStateLabel:Record<Booking['state'],string>={
  requested:'Requested',held:'Held',confirmed:'Officially confirmed',cancelled:'Cancelled',
}
export const bookingProblem:Record<Extract<BookingOutcome,{reason:string}>['reason'],string>={
  room_unsuitable:'Choose a room that fits the group and its accessibility and equipment needs.',
  slot_unavailable:'Choose another time or room. The reservation did not change.',
}

const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const boundedNumber=(v:unknown,min:number,max:number)=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=min&&v<=max
const text=(v:unknown,max:number):v is string=>typeof v==='string'&&v.trim().length>0&&v.length<=max
const equipment=(v:unknown)=>Array.isArray(v)&&v.length<=12&&new Set(v).size===v.length
  &&v.every(item=>typeof item==='string'&&/^[a-z][a-z0-9_-]{0,39}$/.test(item))
const time=(v:unknown):v is string=>typeof v==='string'&&Number.isFinite(Date.parse(v))
const identifyRoom=(v:Pick<Room,'id'|'name'>|null)=>v&&typeof v.id==='string'&&uuid.test(v.id)&&text(v.name,160)
const buffer=(v:unknown)=>boundedNumber(v,0,240)
const policyMode=(v:unknown)=>v==='required'||v==='official_not_required'
const validReference=(r:WorkReferenceValue|undefined,term:string)=>r?.termId===term
  &&text(r.termLabel,200)&&typeof r.value==='string'&&/^[A-Z][A-Z0-9_]{0,39}-[0-9]{3,19}$/.test(r.value)
const validRoom=(room:Room)=>identifyRoom(room)&&boundedNumber(room.capacity,1,10000)
  &&typeof room.accessible==='boolean'&&equipment(room.equipment)&&buffer(room.setupMinutes)&&buffer(room.cleanupMinutes)
const namedSlot=(slot:NamedSlot)=>identifyRoom(slot.room)&&time(slot.startsAt)&&time(slot.endsAt)
  &&Date.parse(slot.startsAt)<Date.parse(slot.endsAt)

function bookingShape(v:unknown,term:string,request:string):v is Booking {
  if(!v||typeof v!=='object')return false
  const b=v as Booking
  return b.requestId===request&&boundedNumber(b.version,1,2147483647)&&boundedNumber(b.sourceRevision,1,2147483647)
    &&validReference(b.reference,term)
    &&Boolean(identifyRoom(b.room))&&time(b.startsAt)&&time(b.endsAt)&&Date.parse(b.startsAt)<Date.parse(b.endsAt)
    &&buffer(b.setupMinutes)&&buffer(b.cleanupMinutes)&&text(b.purpose,1000)&&boundedNumber(b.attendees,1,10000)
    &&equipment(b.equipment)&&[b.accessible,b.holdExpired,b.requestChanged].every(flag=>typeof flag==='boolean')
    &&['requested','held','confirmed','cancelled'].includes(b.state)&&(b.state==='held'?time(b.holdUntil):b.holdUntil===null)
    &&(b.evidence===null?b.state!=='confirmed':Boolean(b.evidence&&['school_record','official_not_required'].includes(b.evidence.kind)
      &&boundedNumber(b.evidence.version,1,b.version)&&boundedNumber(b.evidence.policyVersion,1,2147483647)
      &&(b.state!=='confirmed'||b.evidence.version===b.version)))
}

const bookingErrors:Record<string,string>={
  command_booking_invalid_slot:'Choose a valid start and end time.',
  command_booking_state_changed:'Refresh the request and check its current reservation status.',
  command_booking_request_unavailable:'A current submitted Logistics request and approved room policy are required.',
  command_booking_policy_changed:'The room policy changed. Refresh and review the current requirements.',
  command_booking_request_slot_changed:'Ask the requester to update the proposed room or time before confirming.',
  command_booking_official_evidence_required:'Attach the official reservation evidence and enter its school reference.',
  command_booking_slot_unavailable:'This slot is no longer available. Choose a different room or time. Your entries are kept.',
  command_booking_room_unsuitable:'Choose a room that fits the group and its accessibility and equipment needs.',
}
const slotArgs=(slot:Slot)=>({p_room_id:slot.room,p_starts_at:slot.startsAt,p_ends_at:slot.endsAt})

export function createRoomBookingApi(ready:ReturnType<typeof createSupabaseClient>) {
  async function client(){
    const value=await ready
    if(!value)throw Error('Room booking is unavailable')
    return value
  }
  return {
    async rooms(term:string):Promise<RoomCatalogue> {
      const {data,error}=await (await client()).rpc('read_booking_rooms',{p_term_id:term})
      const value=data as RoomCatalogue|null
      if(error||!value||!Array.isArray(value.rooms)||(value.policyVersion===null?
        value.evidenceMode!==null||value.rooms.length>0:!boundedNumber(value.policyVersion,1,2147483647)||!policyMode(value.evidenceMode))
        ||!value.rooms.every(validRoom))throw Error('Rooms could not be checked')
      return value
    },
    async booking(term:string,request:string):Promise<Booking|null>{
      const {data,error}=await (await client()).rpc('read_room_booking',{p_term_id:term,p_request_id:request})
      if(error||data!==null&&!bookingShape(data,term,request))throw Error('Reservation could not be checked')
      return data
    },
    async workspace(term:string,request:string,window?:Pick<Slot,'startsAt'|'endsAt'>):Promise<BookingWorkspace|null>{
      const {data,error}=await (await client()).rpc('read_room_booking_workspace',{
        p_term_id:term,p_request_id:request,p_starts_at:window?.startsAt??null,p_ends_at:window?.endsAt??null,
      })
      if(!error&&data===null)return null
      const w=data as BookingWorkspace|null
      if(error||!w||!validReference(w.reference,term)||!text(w.requestTitle,240)
        ||!(w.service===null||typeof w.service==='string')
        ||!(w.booking===null||bookingShape(w.booking,term,request)&&w.booking.reference.value===w.reference.value)
        ||![w.requester,w.canRequest,w.canDecide,w.canCancel].every(v=>typeof v==='boolean')
        ||!(w.policyVersion===null?w.evidenceMode===null&&w.maxHoldMinutes===null:
          boundedNumber(w.policyVersion,1,2147483647)&&policyMode(w.evidenceMode)&&boundedNumber(w.maxHoldMinutes,1,120))
        ||!Array.isArray(w.rooms)||!w.rooms.every(r=>validRoom(r)&&(r.available===null||typeof r.available==='boolean'))
        ||!(w.availabilityWindow===null||w.availabilityWindow&&time(w.availabilityWindow.startsAt)&&time(w.availabilityWindow.endsAt)
          &&Date.parse(w.availabilityWindow.startsAt)<Date.parse(w.availabilityWindow.endsAt))
        ||!(w.officialReference===null||text(w.officialReference,500))
        ||!Array.isArray(w.schoolFiles)||!w.schoolFiles.every(name=>text(name,160))
        ||!boundedNumber(w.offerVersion,0,2147483647)
        ||!(w.alternative===null||w.alternative&&namedSlot(w.alternative)&&typeof w.alternative.available==='boolean')
        ||!(w.desiredSlot===null||w.desiredSlot&&namedSlot(w.desiredSlot))
        ||!(w.contact===null||w.contact&&uuid.test(w.contact.id)&&text(w.contact.name,240))
        ||!Array.isArray(w.evidence)||!w.evidence.every(e=>e&&uuid.test(e.id)&&time(e.createdAt)
          &&Array.isArray(e.names)&&e.names.length>0&&e.names.every(name=>text(name,240))))
        throw Error('Room booking details could not be checked')
      return w
    },
    async run(command:BookingCommand,key:string):Promise<CommandResult<BookingOutcome>>{
      try{
        const c=await client()
        const common={p_term_id:command.term,p_request_id:command.request,p_expected_version:command.version,p_reason:command.reason,p_key:key}
        const response=command.kind==='request'?await c.rpc('request_booking',{
          ...common,...slotArgs(command.slot),p_purpose:command.purpose,p_attendees:command.attendees,
          p_accessible:command.accessible,p_equipment:command.equipment,
        }):command.kind==='hold'?await c.rpc('hold_booking',{...common,p_minutes:command.minutes}):
          command.kind==='confirm'?await c.rpc('confirm_booking',{
            ...common,...slotArgs(command.slot),p_policy_version:command.policyVersion,
            p_evidence_manifest_id:command.manifest,p_official_reference:command.officialReference,
          }):command.kind==='offer'?await c.rpc('offer_room_alternative',{
            ...common,...slotArgs(command.slot),p_policy_version:command.policyVersion,p_expected_offer_version:command.offerVersion,
          }):await c.rpc('cancel_booking',common)
        if(response.error){
          const friendly=Object.hasOwn(bookingErrors,response.error.message)?bookingErrors[response.error.message]:null
          return {ok:false,error:friendly?{...mapCommandError(response.error),message:friendly}:mapCommandError(response.error)}
        }
        const v=response.data as unknown as BookingOutcome|null
        if(command.kind==='offer'){
          if(v?.outcome==='offered'&&v.offerVersion===command.offerVersion+1)return {ok:true,value:v}
          throw Error('Room alternative could not be confirmed')
        }
        if(v?.outcome==='offered')throw Error('Reservation outcome could not be confirmed')
        const matching=v?.booking===null||bookingShape(v?.booking,command.term,command.request)
        if(v&&matching){
          if(v.outcome==='saved'&&v.booking.version===command.version+1&&v.booking.state===
            ({request:'requested',hold:'held',confirm:'confirmed',cancel:'cancelled'} as const)[command.kind])
            return {ok:true,value:v}
          if(v.outcome==='conflict'&&v.reason==='slot_unavailable'||v.outcome==='blocked'&&v.reason==='room_unsuitable')
            return {ok:true,value:v}
        }
        throw Error('Reservation outcome could not be confirmed')
      }catch{return {ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}}
    },
  }
}
export type RoomBookingApi=ReturnType<typeof createRoomBookingApi>
