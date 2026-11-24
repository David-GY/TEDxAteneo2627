import { bounded } from '../files/validation.ts'

export type CalendarFaultCode = 'retry' | 'reconnect' | 'conflict'
export class CalendarFault extends Error {
  constructor(readonly code: CalendarFaultCode) { super(code) }
}

export type CoreEvent = {
  title:string;allDay:boolean;startOn:string|null;endOn:string|null;startsAt:string|null;endsAt:string|null
}
export type CalendarChange = {id:string;version:number;tombstone:boolean;etag:string|null;event:CoreEvent|null}
type RemoteDate = {date?:string;dateTime?:string}
type RemoteEvent = {
  id?:string;status?:string;etag?:string;summary?:string;start?:RemoteDate;end?:RemoteDate
  extendedProperties?:{private?:Record<string,string>;shared?:Record<string,string>}
  description?:string;location?:string;attendees?:unknown[];attendeesOmitted?:boolean
  recurrence?:unknown[];recurringEventId?:string;attachments?:unknown[];conferenceData?:unknown
}

const root='https://www.googleapis.com/calendar/v3'
const timeZone='Asia/Manila'
const eventId=/^[a-v0-9]{5,1024}$/
export const calendarId=/^[a-z0-9._-]{1,160}@group\.calendar\.google\.com$/i

export function googleCalendar(fetcher: typeof fetch=fetch) {
  async function request(access:string,url:URL,method='GET',payload?:unknown,etag?:string) {
    const headers:Record<string,string>={Authorization:'Bearer '+access}
    if (payload) headers['Content-Type']='application/json'
    if (etag) headers['If-Match']=etag
    try {
      return await fetcher(url,{method,headers,body:payload?JSON.stringify(payload):undefined,redirect:'error',signal:AbortSignal.timeout(6000)})
    } catch { throw new CalendarFault('retry') }
  }
  async function read<T>(response:Response):Promise<T> {
    try {return JSON.parse(new TextDecoder().decode(await bounded(response.body,32768))) as T}
    catch {throw new CalendarFault('retry')}
  }
  async function check(response:Response) {
    if (response.ok) return
    if (response.status===401) throw new CalendarFault('reconnect')
    if (response.status===403) {
      const body=await read<{error?:{errors?:{reason?:string}[]}}>(response).catch(()=>null)
      if (body?.error?.errors?.some(issue=>['rateLimitExceeded','userRateLimitExceeded','quotaExceeded'].includes(issue.reason??'')))
        throw new CalendarFault('retry')
      throw new CalendarFault('reconnect')
    }
    if (response.status===429 || response.status>=500) throw new CalendarFault('retry')
    throw new CalendarFault('conflict')
  }
  async function target(access:string,id:string) {
    if (!calendarId.test(id)) throw new CalendarFault('reconnect')
    const url=new URL(root+'/users/me/calendarList/'+encodeURIComponent(id))
    url.searchParams.set('fields','id,summary,primary,accessRole,timeZone,deleted')
    const response=await request(access,url)
    if (response.status===404) throw new CalendarFault('reconnect')
    await check(response)
    const record=await read<{id:string;summary:string;primary?:boolean;accessRole:string;timeZone:string;deleted?:boolean}>(response)
    if (record.id!==id || record.primary || record.deleted || record.accessRole!=='owner' || record.timeZone!==timeZone
      || !record.summary?.trim()) throw new CalendarFault('reconnect')
    return record.summary
  }

  const safeRemote = (remote:RemoteEvent,id:string) => remote.id===id && remote.status==='confirmed'
    && remote.extendedProperties?.private?.workspaceEvent===id && !remote.attendees?.length && !remote.attendeesOmitted
    && !remote.recurrence?.length && !remote.recurringEventId && !remote.attachments?.length && !remote.conferenceData
    && typeof remote.etag==='string' && /^"[^"\r\n]{1,200}"$/.test(remote.etag)

  function matches(remote:RemoteEvent,event:CoreEvent) {
    if (remote.summary!==event.title || remote.description || remote.location) return false
    if (event.allDay) return remote.start?.date===event.startOn && remote.end?.date===event.endOn
    return Boolean(remote.start?.dateTime && remote.end?.dateTime && event.startsAt && event.endsAt
      && Date.parse(remote.start.dateTime)===Date.parse(event.startsAt) && Date.parse(remote.end.dateTime)===Date.parse(event.endsAt))
  }

  async function apply(access:string,calendar:string,change:CalendarChange,verify:()=>Promise<void>=async()=>{}) {
    if (!eventId.test(change.id) || !calendarId.test(calendar)) throw new CalendarFault('conflict')
    const collection=new URL(root+'/calendars/'+encodeURIComponent(calendar)+'/events')
    const item=new URL(collection.href+'/'+change.id)
    const response=await request(access,item)
    let remote:RemoteEvent|null=null
    if (response.status!==404 && response.status!==410) {
      await check(response)
      remote=await read<RemoteEvent>(response)
    }
    const missing=!remote || remote.status==='cancelled'
    if (change.tombstone) {
      if (missing) return {etag:null}
      if (!remote || !safeRemote(remote,change.id)) throw new CalendarFault('conflict')
      item.searchParams.set('sendUpdates','none')
      await verify()
      const removed=await request(access,item,'DELETE',undefined,remote.etag)
      if (removed.status!==404 && removed.status!==410) await check(removed)
      return {etag:null}
    }
    const event=change.event
    if (!event || (missing&&(change.etag||response.status===410||remote?.status==='cancelled')))
      throw new CalendarFault('conflict')
    if (remote) {
      if (!safeRemote(remote,change.id)) throw new CalendarFault('conflict')
      if (matches(remote,event)) return {etag:remote.etag!}
      if (remote.etag!==change.etag) throw new CalendarFault('conflict')
    }
    const body={id:change.id,summary:event.title,
      start:event.allDay?{date:event.startOn}:{dateTime:event.startsAt,timeZone},
      end:event.allDay?{date:event.endOn}:{dateTime:event.endsAt,timeZone},
      extendedProperties:{private:{workspaceEvent:change.id}},
    }
    const endpoint=remote?item:collection
    endpoint.searchParams.set('sendUpdates','none')
    await verify()
    const written=await request(access,endpoint,remote?'PUT':'POST',body,remote?.etag)
    if (written.status===409 && !remote) throw new CalendarFault('retry')
    await check(written)
    const confirmed=await read<RemoteEvent>(written)
    if (!safeRemote(confirmed,change.id) || !matches(confirmed,event)) throw new CalendarFault('conflict')
    return {etag:confirmed.etag!}
  }
  return {target,apply}
}
