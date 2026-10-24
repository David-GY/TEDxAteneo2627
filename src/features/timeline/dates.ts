const dayMs=86_400_000
export const eventDay='2027-04-17'
export type Scale='week'|'month'
export function calendarDay(value:string):string{
 if(!/^\d{4}-\d{2}-\d{2}$/.test(value))throw new RangeError('Use a calendar date in YYYY-MM-DD format.')
 const [year,month,day]=value.split('-').map(Number),date=new Date(0)
 date.setUTCFullYear(year,month-1,day);date.setUTCHours(0,0,0,0)
 if(year<1||year>9999||date.toISOString().slice(0,10)!==value)throw new RangeError('Calendar date is invalid.')
 return value
}
function epoch(day:string){return Date.parse(calendarDay(day)+'T00:00:00Z')}
export function addDays(day:string,amount:number):string{
 if(!Number.isSafeInteger(amount))throw new RangeError('Day offset must be an integer.')
 const date=new Date(epoch(day)+amount*dayMs)
 if(!Number.isFinite(date.getTime())||date.getUTCFullYear()<1||date.getUTCFullYear()>9999)throw new RangeError('Date is outside the supported range.')
 return date.toISOString().slice(0,10)
}
export function manilaDay(timestamp:string):string{
 if(!/^\d{4}-\d{2}-\d{2}T/.test(timestamp)||!/(Z|[+-]\d{2}:\d{2})$/i.test(timestamp))throw new RangeError('Timestamp needs an explicit time-zone offset.')
 calendarDay(timestamp.slice(0,10));const date=new Date(timestamp)
 if(!Number.isFinite(date.getTime()))throw new RangeError('Timestamp is invalid.')
 const parts=new Intl.DateTimeFormat('en',{timeZone:'Asia/Manila',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(date)
 const part=(name:string)=>parts.find(p=>p.type===name)!.value
 return calendarDay(part('year').padStart(4,'0')+'-'+part('month')+'-'+part('day'))
}
export function displayEndDay(dueOn:string|null,dueAt:string|null):string|null{
 if(dueOn!==null&&dueAt!==null)throw new RangeError('A work item must have only one authoritative deadline.')
 return dueOn!==null?calendarDay(dueOn):dueAt!==null?manilaDay(dueAt):null
}
export type Schedule={kind:'range';start:string;end:string;days:number}|{kind:'deadline';end:string}|{kind:'unscheduled';start:string|null;missing:'end'|'start_and_end'}
export function schedule(startOn:string|null,dueOn:string|null,dueAt:string|null):Schedule{
 const start=startOn===null?null:calendarDay(startOn),end=displayEndDay(dueOn,dueAt)
 if(!end)return{kind:'unscheduled',start,missing:start?'end':'start_and_end'}
 if(!start)return{kind:'deadline',end}
 if(start>end)throw new RangeError('Planned start must not follow the deadline.')
 return{kind:'range',start,end,days:(epoch(end)-epoch(start))/dayMs+1}
}
export function windowFor(anchor:string,scale:Scale):{start:string;end:string}{
 calendarDay(anchor)
 if(scale==='week'){const weekday=new Date(epoch(anchor)).getUTCDay(),start=addDays(anchor,-((weekday+6)%7));let end:string;try{end=addDays(start,6)}catch{end='9999-12-31'}return{start,end}}
 if(scale!=='month')throw new RangeError('Choose week or month.')
 const start=anchor.slice(0,7)+'-01',date=new Date(epoch(start));date.setUTCMonth(date.getUTCMonth()+1)
 if(date.getUTCFullYear()>9999)return{start,end:'9999-12-31'}
 return{start,end:addDays(date.toISOString().slice(0,10),-1)}
}
