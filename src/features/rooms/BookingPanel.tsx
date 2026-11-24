import {useCallback,useEffect,useId,useRef,useState,type FormEvent} from 'react'
import {Link,useSearchParams} from 'react-router'
import {Panel} from '../../components/Page'
import {TextField} from '../../components/TextField'
import {calendarDay,manilaDay} from '../timeline/dates'
import {Files} from '../files/Files'
import type {FilesApi} from '../files/api'
import {bookingProblem,bookingStateLabel,type Booking,type BookingCommand,type BookingWorkspace,type RoomBookingApi,type Slot} from './api'
import './rooms.css'

type Mode='request'|'hold'|'confirm'|'move'|'cancel'|'offer'
const manila=new Intl.DateTimeFormat('en-PH',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Manila'})
const manilaClock=new Intl.DateTimeFormat('en-PH',{timeStyle:'short',timeZone:'Asia/Manila'})
const localTime=(value:string)=>new Date(Date.parse(value)+8*3600000).toISOString().slice(0,16)
const showTime=(value:string)=>manila.format(new Date(value))
const equipmentName=(value:string)=>value.replace(/[_-]/g,' ').replace(/^./,letter=>letter.toUpperCase())
const slotName=(room:string,start:string,end:string)=>room+' · '+showTime(start)+' to '+
  (manilaDay(start)===manilaDay(end)?manilaClock.format(new Date(end)):showTime(end))+' (Manila)'
const controls={
  request:'Review room request',hold:'Place internal hold',confirm:'Confirm official reservation',
  move:'Confirm new reservation time',cancel:'Cancel room booking',offer:'Offer this alternative',
}
function toWindow(start:string,end:string){
  if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(start)||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(end))return
  try{calendarDay(start.slice(0,10));calendarDay(end.slice(0,10))}catch{return}
  const startsAt=Date.parse(start+':00+08:00'),endsAt=Date.parse(end+':00+08:00')
  if(Number.isFinite(startsAt)&&Number.isFinite(endsAt)&&endsAt>startsAt&&endsAt-startsAt<=86400000)
    return {startsAt:new Date(startsAt).toISOString(),endsAt:new Date(endsAt).toISOString()}
}
function draft(booking:Booking|null){
  return {room:booking?.room.id??'',start:booking?localTime(booking.startsAt):'',end:booking?localTime(booking.endsAt):'',
    purpose:booking?.purpose??'',attendees:booking?String(booking.attendees):'',accessible:booking?.accessible??false,
    equipment:booking?.equipment??[],reason:'',manifest:'',officialReference:''}
}
type Entry=ReturnType<typeof draft>
type Edit={mode:Mode;version:number;policyVersion:number|null;offerVersion:number;usingOffer:boolean;fields:Entry;review:boolean;dirty:boolean}
const startEdit=(w:BookingWorkspace,mode:Mode):Edit=>({mode,version:w.booking?.version??0,policyVersion:w.policyVersion,
  offerVersion:w.offerVersion,usingOffer:false,fields:draft(w.booking),review:false,dirty:false})
const availabilityMatches=(w:BookingWorkspace,slot:Pick<Slot,'startsAt'|'endsAt'>)=>!!w.availabilityWindow
  &&Date.parse(w.availabilityWindow.startsAt)===Date.parse(slot.startsAt)
  &&Date.parse(w.availabilityWindow.endsAt)===Date.parse(slot.endsAt)
const allowed=(w:BookingWorkspace,mode:Mode)=>mode==='request'?w.canRequest:mode==='cancel'?w.canCancel:
  w.canDecide&&(mode==='move'?w.booking?.state==='confirmed':w.booking?.state!=='confirmed')

export function RoomBookingPanel({api,term,request,files,refreshToken}:{
  api:RoomBookingApi;term:string;request:string;files?:FilesApi;refreshToken:number
}){
  const [workspace,setWorkspace]=useState<BookingWorkspace|null>(null)
  const [edit,setEdit]=useState<Edit|null>(null)
  const [busy,setBusy]=useState(false),[checking,setChecking]=useState(false)
  const [problem,setProblem]=useState(''),[notice,setNotice]=useState(''),[readFailed,setReadFailed]=useState(false)
  const [slotConflict,setSlotConflict]=useState(false)
  const [pending,setPending]=useState<{command:BookingCommand;key:string}|null>(null)
  const currentRead=useRef(0),running=useRef(false),alive=useRef(false)
  const openedIntake=useRef(false)
  const heading=useRef<HTMLHeadingElement>(null),shouldFocus=useRef(false)
  const receipt=useRef<HTMLParagraphElement>(null)
  const evidenceDisclosure=useRef<HTMLDetailsElement>(null)
  const prefix=useId()+'-room-'

  const load=useCallback(async(window?:Pick<Slot,'startsAt'|'endsAt'>)=>{
    const generation=++currentRead.current
    setChecking(true);setReadFailed(false)
    try{
      const next=await api.workspace(term,request,window)
      if(generation!==currentRead.current)return
      setWorkspace(next)
      if(!next){setEdit(null);setPending(null);setProblem('');setNotice('');return}
      if(next.canRequest&&!next.booking&&!openedIntake.current){
        openedIntake.current=true
        setEdit(current=>current??startEdit(next,'request'))
      }
    }catch{if(generation===currentRead.current)setReadFailed(true)}
    finally{if(generation===currentRead.current)setChecking(false)}
  },[api,term,request])
  useEffect(()=>{
    alive.current=true
    const refresh=()=>{if(!running.current&&document.visibilityState!=='hidden')void load()}
    refresh();window.addEventListener('focus',refresh);document.addEventListener('visibilitychange',refresh)
    const timer=setInterval(refresh,30000)
    return()=>{alive.current=false;currentRead.current++;clearInterval(timer);window.removeEventListener('focus',refresh);document.removeEventListener('visibilitychange',refresh)}
  },[load,refreshToken])
  useEffect(()=>{if(shouldFocus.current){heading.current?.focus();shouldFocus.current=false}},[edit?.mode,edit?.review])
  useEffect(()=>{if(notice)receipt.current?.focus()},[notice])

  function open(mode:Mode){
    if(!workspace)return
    shouldFocus.current=true
    setProblem('');setSlotConflict(false)
    setEdit(startEdit(workspace,mode))
  }
  function update(fields:Partial<Entry>){
    if(!edit||pending||busy)return
    setEdit({...edit,fields:{...edit.fields,...fields},usingOffer:edit.usingOffer&&!('start'in fields||'end'in fields||'room'in fields),dirty:true});setProblem('')
  }
  function useAlternative(){
    if(!workspace?.alternative?.available||!workspace.canRequest||pending)return
    const alt=workspace.alternative
    shouldFocus.current=true
    setProblem('')
    setEdit({mode:'request',version:workspace.booking?.version??0,policyVersion:workspace.policyVersion,
      offerVersion:workspace.offerVersion,usingOffer:true,review:true,dirty:true,fields:{
        ...(edit?.mode==='request'?edit.fields:draft(workspace.booking)),
        room:alt.room.id,start:localTime(alt.startsAt),end:localTime(alt.endsAt),
      }})
  }
  function discard(){
    if(edit?.dirty&&!window.confirm('Discard the changes you entered for this room booking?'))return
    setEdit(null);setProblem('');setSlotConflict(false)
  }
  async function send(command?:BookingCommand){
    const attempt=pending??(command?{command,key:crypto.randomUUID()}:null)
    if(!attempt||running.current)return
    running.current=true;setPending(attempt);setBusy(true);setProblem('');setNotice('');setSlotConflict(false)
    try{
      const result=await api.run(attempt.command,attempt.key)
      if(!alive.current)return
      if(!result.ok){
        if(!result.error.retryable)setPending(null)
        setProblem(result.error.message)
        if(!result.error.retryable)await load(attempt.command.kind==='offer'?attempt.command.slot:undefined)
        return
      }
      setPending(null)
      if(result.value.outcome==='offered'){
        setEdit(null);setNotice('Alternative offered. Logistics confirmation is still pending.');await load();return
      }
      if(result.value.outcome==='saved'){
        setEdit(null)
        setNotice('Saved · '+bookingStateLabel[result.value.booking.state]+'.')
        const disclosure=evidenceDisclosure.current
        if(disclosure&&!disclosure.querySelector('[data-pending-command="true"]'))disclosure.open=false
        await load()
        return
      }
      setProblem(bookingProblem[result.value.reason]+' Your entries are kept.')
      setSlotConflict(result.value.outcome==='conflict')
      shouldFocus.current=true
      setEdit(current=>current&&{...current,review:false})
      await load(attempt.command.kind==='request'||attempt.command.kind==='confirm'?attempt.command.slot:undefined)
    }finally{
      running.current=false
      if(alive.current)setBusy(false)
    }
  }
  if(!workspace)return null
  const w=workspace,b=w.booking
  const latest=b?.version??0
  const stale=!!edit&&(edit.version!==latest||edit.mode!=='cancel'&&edit.policyVersion!==w.policyVersion
    ||(edit.mode==='offer'||edit.usingOffer)&&edit.offerVersion!==w.offerVersion)
  const selectedWindow=edit?toWindow(edit.fields.start,edit.fields.end):undefined
  const roomEditor=edit?.mode==='request'||edit?.mode==='move'||edit?.mode==='offer'
  const requestEditor=edit?.mode==='request'
  const needsEvidence=(edit?.mode==='confirm'||edit?.mode==='move')&&w.evidenceMode==='required'
  const requirements=edit?.fields
  const editingRooms=roomEditor&&requirements?w.rooms.filter(room=>room.capacity>=Number(requirements.attendees)
    &&(!requirements.accessible||room.accessible)&&requirements.equipment.every(item=>room.equipment.includes(item))):[]
  const sameWindow=!!selectedWindow&&w.rooms.some(r=>r.available!==null)&&availabilityMatches(w,selectedWindow)
  const editable=!!edit&&allowed(w,edit.mode)
  const holdMinutes=Math.min(15,w.maxHoldMinutes??15)
  function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    if(!edit||!w||checking||readFailed||pending||stale||!allowed(w,edit.mode))return
    const f=edit.fields,base={term,request,version:edit.version,reason:f.reason.trim()}
    const slot=roomEditor&&selectedWindow?{room:f.room,...selectedWindow}:b?{room:b.room.id,startsAt:b.startsAt,endsAt:b.endsAt}:null
    if(roomEditor&&(!selectedWindow||!editingRooms.some(r=>r.id===f.room))){
      setProblem('Choose a suitable room and enter a valid start and end in Manila, up to 24 hours apart.');return
    }
    if(edit.mode==='request'&&slot){
      if(!f.purpose.trim()||!Number.isInteger(Number(f.attendees))){setProblem('Enter a purpose and the number of people attending.');return}
      if(edit.usingOffer&&!w.alternative?.available){
        setProblem('The offered slot is no longer available. Your other entries are kept.')
        setEdit({...edit,usingOffer:false,review:false});return
      }
      if(!edit.review){shouldFocus.current=true;setEdit({...edit,review:true});return}
      void send({...base,kind:'request',slot,reason:f.purpose.trim(),purpose:f.purpose.trim(),attendees:Number(f.attendees),accessible:f.accessible,equipment:f.equipment})
    }else if(!base.reason){setProblem('Enter the reason for this decision.')}
    else if(edit.mode==='hold')void send({...base,kind:'hold',minutes:holdMinutes})
    else if(edit.mode==='cancel')void send({...base,kind:'cancel'})
    else if(edit.mode==='offer'&&slot&&w.policyVersion!==null)
      void send({...base,kind:'offer',slot,policyVersion:w.policyVersion,offerVersion:w.offerVersion})
    else if(slot&&w.policyVersion!==null){
      if(needsEvidence&&(!w.evidence.some(e=>e.id===f.manifest)||f.officialReference.trim().length<3)){
        setProblem('Select the finalized school evidence and enter its official reference.');return
      }
      void send({...base,kind:'confirm',slot,policyVersion:w.policyVersion,
        manifest:needsEvidence?f.manifest:null,officialReference:needsEvidence?f.officialReference.trim():null})
    }
  }
  return <Panel title="Room booking" className="room-booking" id="room-booking">
    <p><strong>{w.requestTitle}</strong> · {w.reference.value} · {w.reference.termLabel}</p>
    {checking?<p role="status">Checking current booking…</p>:null}
    {readFailed?<p role="alert">Room booking could not be checked. Your entries are kept. Refresh to check access and continue.</p>:null}
    {notice?<p ref={receipt} tabIndex={-1} role="status">{notice}</p>:null}
    {problem?<p role="alert">{problem}</p>:null}
    {!readFailed&&!checking?<BookingDetails workspace={w}/>:null}
    {!readFailed&&!checking&&w.alternative&&w.canRequest&&w.alternative.available&&!pending&&!edit?.usingOffer?
      <button className="button" onClick={useAlternative}>Choose Logistics alternative</button>:null}
    {pending?<div data-pending-command="true"><p>Booking result is being checked. Try the same action again to recover the result.</p>
      <button className="button" disabled={busy||checking||readFailed} onClick={()=>void send()}>Check whether booking saved</button></div>:null}
    <div className="auth-actions">
      {!edit&&!pending&&!readFailed&&!checking?<>
        {w.canRequest?<button className="button" onClick={()=>open('request')}>{b?'Change desired room or time':'Request a room'}</button>:null}
        {w.canDecide&&b?.state!=='confirmed'?<>
          <button className="button" onClick={()=>open('confirm')}>Review official confirmation</button>
          <button className="button button--secondary" onClick={()=>open('offer')}>{w.alternative?'Change proposed alternative':'Propose an alternative'}</button>
          {b?.state!=='held'?<button className="button button--secondary" onClick={()=>open('hold')}>Review internal hold</button>:null}
        </>:null}
        {w.canDecide&&b?.state==='confirmed'?<button className="button" onClick={()=>open('move')}>Change official reservation</button>:null}
        {w.canCancel?<button className="button button--secondary" onClick={()=>open('cancel')}>Review cancellation</button>:null}
      </>:null}
      <button className="button button--secondary" disabled={checking||busy} onClick={()=>void load(selectedWindow)}>Refresh booking status</button>
    </div>
    {edit&&editable&&!readFailed?<form onSubmit={submit} data-unsaved-changes={edit.dirty}>
      <h3 tabIndex={-1} ref={heading}>{edit.review?'Review your desired slot':controls[edit.mode]}</h3>
      {stale?<div role="alert"><p>The booking or policy changed. Review the current details above before using your entries.</p>
        <button type="button" className="button button--secondary" disabled={checking||!!pending} onClick={()=>{
          setEdit({...edit,version:latest,policyVersion:w.policyVersion,offerVersion:w.offerVersion,usingOffer:false,review:false});setProblem('')
        }}>Keep entries and review current booking</button></div>:null}
      {slotConflict&&w.canDecide&&b?.state!=='confirmed'&&(edit.mode==='hold'||edit.mode==='confirm')?
        <button type="button" className="button button--secondary" disabled={busy||checking||!!pending} onClick={()=>{
          shouldFocus.current=true
          setEdit({...edit,mode:'offer',offerVersion:w.offerVersion,review:false});setProblem('');setSlotConflict(false)
        }}>Choose an alternative to offer</button>:null}
      <fieldset disabled={busy||checking||!!pending||stale}>
        {roomEditor&&!edit.review?<div className="room-fields">
          {requestEditor?<>
            <TextField id={prefix+'purpose'} label="Meeting purpose" value={edit.fields.purpose} required maxLength={1000} onChange={e=>update({purpose:e.target.value})}/>
            <TextField id={prefix+'count'} label="People attending" type="number" required min={1} max={10000} value={edit.fields.attendees} onChange={e=>update({attendees:e.target.value})}/>
            <label className="room-check"><input type="checkbox" checked={edit.fields.accessible} onChange={e=>update({accessible:e.target.checked})}/>Accessible room required</label>
            <fieldset><legend>Equipment needed</legend>{[...new Set([...edit.fields.equipment,...w.rooms.flatMap(r=>r.equipment)])].sort().map(item=>
              <label className="room-check" key={item}><input type="checkbox" checked={edit.fields.equipment.includes(item)}
                onChange={e=>update({equipment:e.target.checked?[...edit.fields.equipment,item]:edit.fields.equipment.filter(v=>v!==item)})}/>{equipmentName(item)}</label>)}
              {!w.rooms.some(r=>r.equipment.length)&&!edit.fields.equipment.length?<p>No equipment listed in the room catalogue.</p>:null}
            </fieldset>
          </>:null}
          <TextField id={prefix+'start'} label="Starts in Manila" type="datetime-local" required value={edit.fields.start} onChange={e=>update({start:e.target.value})}/>
          <TextField id={prefix+'end'} label="Ends in Manila" type="datetime-local" required value={edit.fields.end} onChange={e=>update({end:e.target.value})}/>
          <div className="form-field"><label htmlFor={prefix+'room'}>Room (required)</label>
            <select id={prefix+'room'} required value={edit.fields.room} onChange={e=>update({room:e.target.value})}>
              <option value="">Choose a room</option>{editingRooms.map(r=><option value={r.id} key={r.id}>{r.name} · up to {r.capacity}{sameWindow&&r.available===false?' · unavailable for this time':''}</option>)}
            </select></div>
          <button type="button" className="button button--secondary" disabled={!selectedWindow} onClick={()=>void load(selectedWindow)}>Check room availability</button>
          {sameWindow?<div role="status"><p>Availability is checked again when Logistics confirms.</p>
            {editingRooms.some(r=>r.available&&r.id!==edit.fields.room)?<ul>{editingRooms.filter(r=>r.available&&r.id!==edit.fields.room).map(r=>
              <li key={r.id}><button type="button" className="button button--secondary" onClick={()=>update({room:r.id})}>Choose {r.name} at this time</button></li>)}</ul>:null}
            {!editingRooms.some(r=>r.available)?<p>Choose a different start and end to check another time.</p>:null}</div>:null}
          <p>Request each recurring session separately on its own Logistics request.</p>
        </div>:null}
        {edit.review&&selectedWindow?<div>
          <p>{slotName(w.rooms.find(room=>room.id===edit.fields.room)?.name??'Selected room',selectedWindow.startsAt,selectedWindow.endsAt)}</p>
          <p className="record-text">{edit.fields.purpose} · {edit.fields.attendees} attending{edit.fields.accessible?' · accessible room':''}{edit.fields.equipment.length?' · '+edit.fields.equipment.map(equipmentName).join(', '):''}</p>
          <p>Logistics will check the slot and record official confirmation.</p>
          {b?.state==='held'?<p>Sending a new slot releases the current internal hold.</p>:null}
          <button type="button" className="button button--secondary" onClick={()=>{shouldFocus.current=true;setEdit({...edit,review:false})}}>Back to change details</button>
        </div>:null}
        {edit.mode==='hold'?<p>Hold this desired slot for up to {holdMinutes} minutes. The calendar appears after official confirmation.</p>:null}
        {edit.mode==='cancel'?<p>{b?.state==='confirmed'?'Release this official reservation and remove its calendar entry.':'Close this room proposal.'} Its details stay in the request history.</p>:null}
        {needsEvidence?<div className="room-fields">
          <p>Use the school record that covers the room and time you are confirming.</p>
          <div className="form-field"><label htmlFor={prefix+'evidence'}>Finalized school evidence (required)</label>
            <select id={prefix+'evidence'} value={edit.fields.manifest} required onChange={e=>update({manifest:e.target.value})}><option value="">Choose finalized evidence</option>
              {w.evidence.map(e=><option key={e.id} value={e.id}>{e.names.join(', ')} · {showTime(e.createdAt)}</option>)}</select></div>
          {!w.evidence.length?<p>Attach and finalize the school record below, or ask the current evidence custodian for help.</p>:null}
          <TextField id={prefix+'reference'} label="Official school reference" required minLength={3} maxLength={500} value={edit.fields.officialReference} onChange={e=>update({officialReference:e.target.value})}/>
        </div>:null}
        {(edit.mode==='confirm'||edit.mode==='move')&&w.evidenceMode==='official_not_required'?<p>The current approved room policy waives a school record. Confirm the chosen slot as Logistics.</p>:null}
        {!requestEditor?<TextField id={prefix+'reason'} label={edit.mode==='cancel'?'Cancellation reason':'Decision reason'} required maxLength={2000} value={edit.fields.reason} onChange={e=>update({reason:e.target.value})}/>:null}
        <div className="auth-actions">
          <button className="button" type="submit">{edit.review?(edit.usingOffer?'Request this alternative':'Send room request to Logistics'):edit.mode==='cancel'?'Confirm cancellation':controls[edit.mode]}</button>
          <button className="button button--secondary" type="button" onClick={discard}>Close editor</button>
        </div>
      </fieldset>
    </form>:null}
    {w.canDecide&&w.evidenceMode==='required'&&files?<details ref={evidenceDisclosure} className="work-section" hidden={readFailed}><summary>Attach the school record</summary>
      <Files api={files} workId={request} uploadsOnly roomEvidence onFinalized={manifest=>{
        setEdit(current=>current&&(current.mode==='confirm'||current.mode==='move')?
          {...current,fields:{...current.fields,manifest},dirty:true}:current)
        void load(selectedWindow)
      }}/></details>:null}
    {edit&&!editable&&!checking&&!pending?<p role="status">This action is unavailable on the current booking. <button type="button" className="button button--secondary" onClick={discard}>Close editor</button></p>:null}
  </Panel>
}

function BookingDetails({workspace:w}:{workspace:BookingWorkspace}){
  const [search]=useSearchParams()
  const b=w.booking
  const term=search.has('term')?'&term='+w.reference.termId:''
  const contact=<Link className="button button--secondary" to={w.contact?'/people?contact='+w.contact.id+term:
    term?'/people?'+term.slice(1):'/people'}>{w.contact?.name??'Find a service contact'}</Link>
  if(!b)return <><p>Choose a room and time for Logistics to review.</p>{contact}</>
  const room=availabilityMatches(w,b)?w.rooms.find(room=>room.id===b.room.id):undefined
  return <>
    <p><strong>{bookingStateLabel[b.state]}</strong></p>
    {w.desiredSlot&&(b.state==='confirmed'||b.state==='cancelled')?<p>Requester’s desired slot · {slotName(w.desiredSlot.room.name,w.desiredSlot.startsAt,w.desiredSlot.endsAt)}</p>:null}
    <p>{b.state==='confirmed'?'Official reservation':b.state==='cancelled'?'Cancelled slot':'Desired slot'} · {slotName(b.room.name,b.startsAt,b.endsAt)}</p>
    <p className="record-text">{b.purpose} · {b.attendees} attending{b.accessible?' · accessible room':''}{b.equipment.length?' · '+b.equipment.map(equipmentName).join(', '):''}</p>
    {b.state==='requested'||b.state==='held'?<>
      <p>{room?.available===false?'This time is unavailable. Ask Logistics about another room or time, or change your proposal when permitted.':
        b.state==='held'?'Logistics must record official confirmation before the booking appears in the calendar.':'Waiting for Logistics to check the requested slot and record official confirmation.'}</p>
      {room?.available&&w.canDecide?<p>Available at the last check. Confirmation checks availability again.</p>:null}
      {b.holdUntil?<p>Hold expires {showTime(b.holdUntil)} (Manila).</p>:null}
      {b.holdExpired?<p>The internal hold expired. Logistics can check availability again.</p>:null}
      {b.requestChanged?<p>The submission changed. The requester must review and save the room proposal again.</p>:null}
    </>:null}
    {b.evidence?<p>{b.evidence.kind==='school_record'?'Official school evidence recorded':'Approved evidence exception recorded'}{w.officialReference?' · '+w.officialReference:''}</p>:null}
    {w.schoolFiles.length?<p className="record-text">Finalized school evidence · {w.schoolFiles.join(', ')}</p>:null}
    {w.alternative?<div>
      <p><strong>Alternative from Logistics</strong> · {slotName(w.alternative.room.name,w.alternative.startsAt,w.alternative.endsAt)}</p>
      <p>{w.alternative.available?'The requester can choose this slot for Logistics to confirm.':'This alternative is no longer available. Choose another time or ask Logistics for help.'}</p>
    </div>:null}
    {b.state==='confirmed'?<Link className="button button--secondary" to={'/calendar?booking='+b.requestId+term}>Open confirmed calendar entry</Link>:null}
    {b.state==='cancelled'?<p>This booking has no active calendar entry.</p>:null}
    <p>{w.service??'Logistics'} booking contact</p>{contact}
  </>
}
