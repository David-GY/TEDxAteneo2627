// Read-only schedule proposals. No dispatcher imports this module and no clock is registered.
export type NotificationProposal={version:1;audience:'current_assignees';channel:'in_app'|'email'|'telegram';mode:'immediate'|'digest'|'mute';beforeDays:number;dueDay:boolean;overdueEveryDays:number;hour:number;quietStart:number;quietEnd:number;template:'action_link'}
export const defaultProposal=():NotificationProposal=>({version:1,audience:'current_assignees',channel:'in_app',mode:'digest',beforeDays:2,dueDay:true,overdueEveryDays:1,hour:8,quietStart:20,quietEnd:8,template:'action_link'})
export function validProposal(value:unknown):value is NotificationProposal{
 if(!value||typeof value!=='object'||Object.getPrototypeOf(value)!==Object.prototype)return false
 const r=value as Record<string,unknown>,keys=['version','audience','channel','mode','beforeDays','dueDay','overdueEveryDays','hour','quietStart','quietEnd','template']
 const whole=(v:unknown,min:number,max:number)=>typeof v==='number'&&Number.isInteger(v)&&v>=min&&v<=max
 return Object.keys(r).length===keys.length&&Object.keys(r).every(k=>keys.includes(k))&&r.version===1&&r.audience==='current_assignees'&&typeof r.channel==='string'&&['in_app','email','telegram'].includes(r.channel)&&typeof r.mode==='string'&&['immediate','digest','mute'].includes(r.mode)&&whole(r.beforeDays,1,7)&&typeof r.dueDay==='boolean'&&whole(r.overdueEveryDays,1,7)&&whole(r.hour,0,23)&&whole(r.quietStart,0,23)&&whole(r.quietEnd,0,23)&&r.quietStart!==r.quietEnd&&r.template==='action_link'
}
export function externalTemplate(template:unknown){if(template!=='action_link')throw Error('Unsupported notification template');return 'You have an update. Open your workspace to check the current permitted action.'}
const dayMs=86400000,offset=8*3600000
function day(value:string){if(!/^\d{4}-\d{2}-\d{2}$/.test(value))throw Error('Use a valid Manila calendar date');const n=Date.parse(value+'T00:00:00Z');if(!Number.isFinite(n)||new Date(n).toISOString().slice(0,10)!==value)throw Error('Use a valid Manila calendar date');return n}
export type PlannedReminder={key:string;event:'before_due'|'due'|'overdue';logicalDay:string;at:string;available:boolean;optionalDelivery:boolean;requiredWorkVisible:true}
export function planReminder(rule:NotificationProposal,work:string,dueOn:string,from:string,to:string):PlannedReminder[]{
 if(!validProposal(rule)||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(work))throw Error('Invalid proposal')
 if(![from,to].every(v=>/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?(Z|[+-]\d{2}:\d{2})$/.test(v)))throw Error('Preview instants need an explicit timezone')
 const due=day(dueOn),start=Date.parse(from),end=Date.parse(to)
 if(!Number.isFinite(start)||!Number.isFinite(end)||end<start||end-start>31*dayMs)throw Error('Preview a window of at most31days')
 if(start===end)return[]
 const first=Math.floor((start+offset)/dayMs)*dayMs-2*dayMs,last=Math.floor((end+offset)/dayMs)*dayMs,result:PlannedReminder[]=[]
 for(let d=first;d<=last;d+=dayMs){
  const delta=(d-due)/dayMs,event=delta===-rule.beforeDays?'before_due':delta===0&&rule.dueDay?'due':delta>0&&(delta-1)%rule.overdueEveryDays===0?'overdue':null
  if(!event)continue
  let at=d+rule.hour*3600000-offset
  if(rule.channel!=='in_app'){
   const quiet=rule.quietStart>rule.quietEnd?rule.hour>=rule.quietStart||rule.hour<rule.quietEnd:rule.hour>=rule.quietStart&&rule.hour<rule.quietEnd
   if(quiet)at=d+(rule.quietStart>rule.quietEnd&&rule.hour>=rule.quietStart?dayMs:0)+rule.quietEnd*3600000-offset
  }
  if(at<start||at>=end)continue
  const logicalDay=new Date(d).toISOString().slice(0,10)
  result.push({key:JSON.stringify(['reminder-v1',work.toLowerCase(),dueOn,event,logicalDay,rule.channel]),event,logicalDay,at:new Date(at).toISOString(),available:rule.channel==='in_app',optionalDelivery:false,requiredWorkVisible:true})
 }
 return result.sort((a,b)=>a.at.localeCompare(b.at)||a.key.localeCompare(b.key))
}
export function mergePlannedReminders(rows:PlannedReminder[]){return [...new Map(rows.map(r=>[r.key,r])).values()].sort((a,b)=>a.at.localeCompare(b.at)||a.key.localeCompare(b.key))}
