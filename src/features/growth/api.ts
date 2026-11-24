import {mapCommandError,type CommandResult} from '../../lib/commands'
import type {createSupabaseClient} from '../../lib/supabase'
import type {PrivateAppointment} from '../calendar/ics'

export const categoryLabels={personal:'Personal development',skills:'Skills',collaboration:'Collaboration',role:'Role learning'} as const
export type Category=keyof typeof categoryLabels
export type Relationship={
  id:string;version:number;mentor:string;mentee:string;startsAt:string;endsAt:string
  state:'offered'|'upcoming'|'active'|'ended';asMentor:boolean
}
export type Goal={
  id:string;title:string;category:Category;target:string|null;progress:number;version:number;own:boolean
  sharedWith:string|null;hasSharingRecord:boolean;learner:string|null
}
export type LearningNote={id:string;author:string;body:string|null;nextAction:string|null;at:string}
export type Checkin={
  id:string;relationship:string;title:string|null;startsAt:string;endsAt:string;version:number
  state:'scheduled'|'completed'|'cancelled'|'missed'|'ended';canAct:boolean;canExport:boolean;notes:LearningNote[]
}
export type GrowthWorkspace={
  termLabel:string;editable:boolean;canManage:boolean;relationships:Relationship[];goals:Goal[];checkins:Checkin[]
}
export type Assignment=Omit<Relationship,'asMentor'>&{menteeId:string;mentorId:string;revoked:boolean}
export type Assignments={people:{id:string;name:string;mentor:boolean}[];assignments:Assignment[]}
export type GrowthCommand={term:string}&(
  {kind:'goal';id:string|null;version:number;title:string;category:Category;target:string|null;progress:number}|
  {kind:'share';id:string;version:number;relationship:string|null}|
  {kind:'consent';id:string;version:number;accept:boolean}|
  {kind:'assignment';previous:string|null;version:number|null;mentor:string;mentee:string;startsAt:string;endsAt:string;approval:string}|
  {kind:'checkin';relationship:string;id:string|null;version:number;action:'schedule'|'completed'|'missed'|'cancelled';
    startsAt:string|null;endsAt:string|null;title:string|null}|
  {kind:'note';id:string;version:number;body:string|null;next:string|null})
export type GrowthReceipt={id:string;version:number}

const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v)
const text=(v:unknown):v is string=>typeof v==='string'&&v.trim().length>0
const optionalText=(v:unknown)=>v===null||text(v)
const int=(v:unknown,min=0,max=2147483647)=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=min&&v<=max
const flags=(...v:unknown[])=>v.every(x=>typeof x==='boolean')
const time=(v:unknown):v is string=>typeof v==='string'&&/(Z|[+-]\d{2}:\d{2})$/i.test(v)&&Number.isFinite(Date.parse(v))
const timed=(r:{startsAt:string;endsAt:string})=>time(r.startsAt)&&time(r.endsAt)&&Date.parse(r.startsAt)<Date.parse(r.endsAt)
const relationship=(r:Omit<Relationship,'asMentor'>)=>r&&uuid(r.id)&&int(r.version,1)&&text(r.mentor)&&text(r.mentee)&&timed(r)
  &&['offered','upcoming','active','ended'].includes(r.state)
const goal=(g:Goal)=>g&&uuid(g.id)&&int(g.version,1)&&text(g.title)&&Object.hasOwn(categoryLabels,g.category)
  &&optionalText(g.target)&&int(g.progress,0,100)&&(g.sharedWith===null||uuid(g.sharedWith))
  &&flags(g.own,g.hasSharingRecord)&&optionalText(g.learner)
const note=(n:LearningNote)=>n&&uuid(n.id)&&text(n.author)&&optionalText(n.body)&&optionalText(n.nextAction)&&time(n.at)
const checkin=(c:Checkin)=>c&&uuid(c.id)&&uuid(c.relationship)&&optionalText(c.title)&&int(c.version,1)&&timed(c)
  &&['scheduled','completed','cancelled','missed','ended'].includes(c.state)&&flags(c.canAct,c.canExport)
  &&Array.isArray(c.notes)&&c.notes.every(note)

const explanations:Record<string,string>={
  command_learning_unavailable:'Goals and mentoring are unavailable for the current term.',
  command_mentorship_overlap:'This pair already has an approved assignment during those dates.',
  command_mentorship_changed:'The assignment changed. Check its current dates and consent.',
  command_learning_time_invalid:'Choose a future check-in within the agreed mentoring dates.',
  command_learning_checkin_changed:'Check the current check-in time and status before continuing.',
}

export function createGrowthApi(ready:ReturnType<typeof createSupabaseClient>){
  async function client(){
    const c=await ready
    if(!c)throw Error('Learning workspace unavailable')
    return c
  }
  return {
    async enabled(term:string){
      const {data,error}=await(await client()).rpc('read_learning_entry',{p_term_id:term})
      if(error||typeof data!=='boolean')throw Error('Learning workspace availability could not be checked')
      return data
    },
    async read(term:string):Promise<GrowthWorkspace|null>{
      const {data,error}=await(await client()).rpc('read_learning_workspace',{p_term_id:term})
      if(!error&&data===null)return null
      const v=data as GrowthWorkspace|null
      if(error||!v||!text(v.termLabel)||!flags(v.editable,v.canManage)||!Array.isArray(v.relationships)
        ||!v.relationships.every(r=>relationship(r)&&flags(r.asMentor))
        ||!Array.isArray(v.goals)||!v.goals.every(goal)||!Array.isArray(v.checkins)||!v.checkins.every(checkin))
        throw Error('Learning workspace could not be checked')
      return v
    },
    async assignments(term:string):Promise<Assignments>{
      const {data,error}=await(await client()).rpc('read_mentoring_assignments',{p_term_id:term})
      const v=data as Assignments|null
      if(error||!v||!Array.isArray(v.people)||!v.people.every(p=>p&&uuid(p.id)&&text(p.name)&&flags(p.mentor))
        ||!Array.isArray(v.assignments)||!v.assignments.every(r=>relationship(r)&&uuid(r.mentorId)&&uuid(r.menteeId)&&flags(r.revoked)))
        throw Error('Mentorship assignments could not be checked')
      return v
    },
    async calendar(term:string,id:string,version:number):Promise<PrivateAppointment>{
      const {data,error}=await(await client()).rpc('export_learning_checkin',{p_term_id:term,p_checkin_id:id,p_expected_version:version})
      const v=data as PrivateAppointment|null
      if(error||!v||!uuid(v.uid)||v.version!==version||!timed(v)||!time(v.updatedAt))
        throw Error('The current private check-in could not be exported.')
      return {uid:v.uid,version:v.version,startsAt:v.startsAt,endsAt:v.endsAt,updatedAt:v.updatedAt}
    },
    async exportOwn(term:string){
      const {data,error}=await(await client()).rpc('export_learning_record',{p_term_id:term})
      const v=data as {exportedAt:string;goals:(Pick<Goal,'title'|'category'|'progress'|'target'>&{updatedAt:string})[];authoredNotes:{
        body:string|null;nextAction:string|null;recordedAt:string;checkinStartsAt:string
      }[]}|null
      if(error||!v||!time(v.exportedAt)||!Array.isArray(v.goals)||!v.goals.every(g=>g&&text(g.title)
        &&Object.hasOwn(categoryLabels,g.category)&&int(g.progress,0,100)&&optionalText(g.target)&&time(g.updatedAt))
        ||!Array.isArray(v.authoredNotes)||!v.authoredNotes.every(n=>n&&optionalText(n.body)&&optionalText(n.nextAction)
          &&time(n.recordedAt)&&time(n.checkinStartsAt)))throw Error('Your learning record could not be exported.')
      return {exportedAt:v.exportedAt,goals:v.goals.map(({title,category,target,progress,updatedAt})=>({title,category,target,progress,updatedAt})),
        authoredNotes:v.authoredNotes.map(({body,nextAction,recordedAt,checkinStartsAt})=>({body,nextAction,recordedAt,checkinStartsAt}))}
    },
    async run(q:GrowthCommand,key:string):Promise<CommandResult<GrowthReceipt>>{
      try{
        const c=await client(),base={p_term_id:q.term,p_key:key}
        const response=q.kind==='goal'?await c.rpc('save_learning_goal',{...base,p_goal_id:q.id,p_expected_version:q.version,
          p_title:q.title,p_category:q.category,p_target:q.target,p_progress:q.progress}):
          q.kind==='share'?await c.rpc('share_learning_goal',{...base,p_goal_id:q.id,p_expected_version:q.version,p_mentorship_id:q.relationship}):
          q.kind==='consent'?await c.rpc('respond_mentorship',{...base,p_mentorship_id:q.id,p_expected_version:q.version,p_accept:q.accept}):
          q.kind==='assignment'?await c.rpc('approve_mentorship',{...base,p_mentee_id:q.mentee,p_mentor_id:q.mentor,
            p_starts_at:q.startsAt,p_ends_at:q.endsAt,p_approval_reference:q.approval,p_previous_id:q.previous,p_expected_version:q.version}):
          q.kind==='checkin'?await c.rpc('save_learning_checkin',{...base,p_mentorship_id:q.relationship,p_checkin_id:q.id,
            p_expected_version:q.version,p_action:q.action,p_starts_at:q.startsAt,p_ends_at:q.endsAt,p_title:q.title}):
          await c.rpc('append_learning_note',{...base,p_checkin_id:q.id,p_expected_version:q.version,p_body:q.body,p_next_action:q.next})
        if(response.error){
          const mapped=mapCommandError(response.error),message=explanations[response.error.message]
          return {ok:false,error:typeof message==='string'?{...mapped,message}:mapped}
        }
        const receipt=response.data as GrowthReceipt|null
        if(!receipt||!uuid(receipt.id)||(q.kind==='assignment'?receipt.version!==1:
          receipt.version!==q.version+1||q.id!==null&&receipt.id!==q.id))throw Error()
        return {ok:true,value:receipt}
      }catch{return {ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}}
    },
  }
}
export type GrowthApi=ReturnType<typeof createGrowthApi>
