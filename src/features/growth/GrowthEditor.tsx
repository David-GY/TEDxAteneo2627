import {useId,useRef,useState,type ComponentProps,type FormEvent} from 'react'
import {Panel} from '../../components/Page'
import {TextField} from '../../components/TextField'
import {forgetRecordDrafts} from '../auth/draftScope'
import {useFinDecision} from '../finance/DecisionMemory'
import {categoryLabels,type Assignment,type Assignments,type Category,type Checkin,type Goal,type GrowthApi,type GrowthCommand,type Relationship} from './api'

export const localTime=(value:string)=>new Date(Date.parse(value)+8*3600000).toISOString().slice(0,16)
export const manilaTime=(value:string)=>{
  if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value))return null
  const time=new Date(value+':00+08:00')
  return Number.isFinite(time.getTime())&&localTime(time.toISOString())===value?time.toISOString():null
}
const clean=(value:string)=>value.trim()||null
type InputOptions=Omit<ComponentProps<typeof TextField>,'id'|'label'|'value'|'onChange'>

export type GrowthEdit=
  {kind:'goal';goal?:Goal}|{kind:'share';goal:Goal;choices:Relationship[]}|
  {kind:'schedule';relationship:Relationship;checkin?:Checkin}|{kind:'note';checkin:Checkin}|
  {kind:'assignment';data:Assignments;previous?:Assignment}

const titleFor=(q:GrowthEdit)=>q.kind==='goal'?q.goal?'Edit goal details':'Add a personal goal':
  q.kind==='share'?'Choose a mentor to share with':q.kind==='schedule'?q.checkin?'Change check-in':'Schedule a check-in':
  q.kind==='note'?'Add a check-in note':q.previous?'Approve a replacement mentor':'Approve a mentorship'

export function GrowthEditor({api,term,edit,checking,refresh,saved,close}:{
  api:GrowthApi;term:string;edit:GrowthEdit;checking:boolean;refresh:()=>void;saved:(notice:string)=>void;close:()=>void
}){
  const goal='goal'in edit?edit.goal:undefined
  const checkin='checkin'in edit?edit.checkin:undefined
  const relationship=edit.kind==='schedule'?edit.relationship:undefined
  const previous=edit.kind==='assignment'?edit.previous:undefined
  const entity=goal?.id??checkin?.id??relationship?.id??previous?.id??(edit.kind==='assignment'?'new-assignment':'new-goal')
  const currentVersion=goal?.version??checkin?.version??previous?.version??relationship?.version??0
  const [base,setBase]=useState(currentVersion),[dirty,setDirty]=useState(false),[error,setError]=useState('')
  const id=useId(),running=useRef(false)
  const m=useFinDecision(api,'learning:'+term+':'+entity+':'+edit.kind,{
    title:goal?.title??checkin?.title??'',category:goal?.category??'personal',target:goal?.target??'',
    sharing:goal?.sharedWith??'',startsAt:checkin?localTime(checkin.startsAt):'',
    endsAt:'',duration:checkin?String(Math.round((Date.parse(checkin.endsAt)-Date.parse(checkin.startsAt))/60000)):'30',
    body:'',next:'',mentee:previous?.menteeId??'',mentor:'',approval:'',
  })
  const fields=m.fields,stale=base!==currentVersion
  const success=edit.kind==='goal'?'Goal saved.':edit.kind==='share'?'Goal sharing saved.':
    edit.kind==='schedule'?'Check-in scheduled.':edit.kind==='note'?'Check-in note saved.':'Mentorship approved. Member consent is pending.'
  function change(name:string,value:string){m.change({...fields,[name]:value});setDirty(true);setError('')}
  const input=(name:string,label:string,options:InputOptions={})=><TextField id={id+name} label={label}
    value={fields[name]} onChange={event=>change(name,event.target.value)} {...options}/>
  async function send(command?:GrowthCommand){
    if(running.current)return
    running.current=true
    try{const result=await m.run(command);if(result){setDirty(false);saved(success)}else refresh()}
    finally{running.current=false}
  }
  function submit(event:FormEvent){
    event.preventDefault()
    if(checking||m.locked||stale)return
    if(edit.kind==='goal'&&Object.hasOwn(categoryLabels,fields.category)){
      void send({kind:'goal',term,id:goal?.id??null,version:base,title:fields.title,category:fields.category as Category,target:clean(fields.target),
        progress:goal?.progress??0})
    }else if(edit.kind==='share'){
      if(!edit.choices.some(r=>r.id===fields.sharing)){setError('Choose a current mentor.');return}
      void send({kind:'share',term,id:edit.goal.id,version:base,relationship:fields.sharing})
    }else if(edit.kind==='note'){
      const body=clean(fields.body),next=clean(fields.next)
      if(!body&&!next){setError('Enter a note or an agreed next action.');return}
      void send({kind:'note',term,id:edit.checkin.id,version:base,body,next})
    }else if(edit.kind==='schedule'){
      const startsAt=manilaTime(fields.startsAt),duration=Number(fields.duration)
      if(!startsAt||!Number.isInteger(duration)||duration<1||duration>120){setError('Choose a valid start and duration in Manila.');return}
      const endsAt=new Date(Date.parse(startsAt)+duration*60000).toISOString()
      void send({kind:'checkin',term,relationship:edit.relationship.id,id:checkin?.id??null,version:checkin?base:0,
        action:'schedule',startsAt,endsAt,title:clean(fields.title)})
    }else if(edit.kind==='assignment'){
      const startsAt=manilaTime(fields.startsAt),endsAt=manilaTime(fields.endsAt)
      if(!startsAt||!endsAt||startsAt>=endsAt||fields.mentor===fields.mentee){setError('Use an eligible pair and valid Manila dates.');return}
      void send({kind:'assignment',term,previous:previous?.id??null,version:previous?base:null,mentor:fields.mentor,mentee:fields.mentee,
        startsAt,endsAt,approval:fields.approval})
    }
  }
  return <Panel title={titleFor(edit)} className="growth-editor">
    {goal?<p><strong>{goal.title}</strong></p>:null}
    {relationship?<p>Check-in with {relationship.asMentor?relationship.mentee:relationship.mentor}</p>:null}
    {error||m.error?<p role="alert">{error||m.error}</p>:null}
    <Retry busy={m.busy||checking} pending={!!m.pending} retry={()=>void send()}/>
    {stale&&!m.pending?<div role="alert"><p>Current details changed. Review them before using the entries below.</p>
      <button className="button button--secondary" disabled={checking} onClick={()=>{setBase(currentVersion);m.change(fields);setError('')}}>
        Keep entries and review latest</button></div>:null}
    <form onSubmit={submit} data-unsaved-changes={dirty} data-pending-command={m.locked}>
      <fieldset disabled={m.locked||stale||checking}>
        {edit.kind==='goal'?<>
          {input('title','Goal title',{required:true,maxLength:160})}
          <div className="form-field"><label htmlFor={id+'category'}>Category</label>
            <select id={id+'category'} value={fields.category} onChange={e=>change('category',e.target.value)}>
              {Object.entries(categoryLabels).map(([value,label])=><option value={value} key={value}>{label}</option>)}
            </select></div>
          {input('target','What would progress look like? (optional)',{maxLength:1000})}
        </>:null}
        {edit.kind==='share'?<>
          <p>This mentor will see the goal, target and progress during the active assignment. You can stop sharing anytime.</p>
          <div className="form-field"><label htmlFor={id+'sharing'}>Current mentor</label>
            <select id={id+'sharing'} value={fields.sharing} required onChange={e=>change('sharing',e.target.value)}>
              <option value="">Choose a mentor</option>{edit.choices.map(r=><option key={r.id} value={r.id}>{r.mentor}</option>)}
            </select></div>
        </>:null}
        {edit.kind==='schedule'?<>
          {input('startsAt','Start in Manila',{required:true,type:'datetime-local'})}
          <div className="form-field"><label htmlFor={id+'duration'}>Duration</label>
            <select id={id+'duration'} value={fields.duration} onChange={e=>change('duration',e.target.value)}>
              {[...new Set([15,30,45,60,90,120,Number(fields.duration)])].sort((a,b)=>a-b)
                .map(n=><option key={n} value={n}>{n} minutes</option>)}
            </select></div>
          {input('title','Check-in title (optional)',{maxLength:160})}
        </>:null}
        {edit.kind==='note'?<>
          <p>Both participants can read this note during the assignment. It stays in the learner’s history with your name attached.</p>
          <div className="form-field"><label htmlFor={id+'body'}>Note (optional)</label>
            <textarea id={id+'body'} value={fields.body} onChange={e=>change('body',e.target.value)} maxLength={2000} rows={3}/></div>
          {input('next','Agreed next action (optional)',{maxLength:1000})}
        </>:null}
        {edit.kind==='assignment'?<>
          {previous?<p>{previous.mentee} · Previous mentor {previous.mentor}. The replacement needs the member’s consent and new sharing choices.</p>:
            <div className="form-field"><label htmlFor={id+'mentee'}>Member</label>
              <select id={id+'mentee'} value={fields.mentee} required onChange={e=>change('mentee',e.target.value)}>
                <option value="">Choose a member</option>{edit.data.people.map(person=><option key={person.id} value={person.id}>{person.name}</option>)}
              </select></div>}
          <div className="form-field"><label htmlFor={id+'mentor'}>Approved mentor</label>
            <select id={id+'mentor'} value={fields.mentor} required onChange={e=>change('mentor',e.target.value)}>
              <option value="">Choose an eligible mentor</option>{edit.data.people.filter(p=>p.mentor&&p.id!==fields.mentee&&p.id!==previous?.mentorId)
                .map(person=><option key={person.id} value={person.id}>{person.name}</option>)}
            </select></div>
          {input('startsAt','Effective from in Manila',{type:'datetime-local',required:true})}
          {input('endsAt','Effective until in Manila',{type:'datetime-local',required:true})}
          {input('approval','School approval reference',{required:true,minLength:3,maxLength:500})}
        </>:null}
        <button className="button" type="submit">{edit.kind==='goal'?'Save goal':edit.kind==='share'?'Share goal':edit.kind==='schedule'?
          'Save check-in':edit.kind==='note'?'Save check-in note':'Approve assignment'}</button>
      </fieldset>
      <button className="button button--secondary" disabled={m.locked} type="button" onClick={()=>{
        if(!dirty||window.confirm('Discard these entries?')){forgetRecordDrafts(entity);close()}
      }}>Close editor</button>
    </form>
  </Panel>
}

function Retry({busy,pending,retry}:{busy:boolean;pending:boolean;retry:()=>void}){
  return pending?<div data-pending-command="true"><p>Checking the result. Recover the same saved action.</p>
    <button className="button" disabled={busy} onClick={retry}>Check whether saved</button></div>:null
}

export function GrowthAction({api,command,label,notice,checking,saved,refresh,confirm}:{
  api:GrowthApi;command:GrowthCommand;label:string;notice:string;checking:boolean;
  saved:(notice:string)=>void;refresh:()=>void;confirm?:string
}){
  const key='learning:'+command.term+':'+('id'in command?command.id:'assignment')+':'+label
  const m=useFinDecision(api,key,{})
  async function run(retry=false){
    if(!retry&&confirm&&!window.confirm(confirm))return
    const result=await m.run(retry?undefined:command)
    if(result)saved(notice);else refresh()
  }
  return <div data-pending-command={m.locked}>
    {m.error?<p role="alert">{m.error}</p>:null}
    <Retry busy={m.busy||checking} pending={!!m.pending} retry={()=>void run(true)}/>
    {!m.pending?<button className="button button--secondary" disabled={checking||m.busy} onClick={()=>void run()}>{label}</button>:null}
  </div>
}

export function GoalProgress({goal,api,term,checking,refresh,saved}:{
  goal:Goal;api:GrowthApi;term:string;checking:boolean;refresh:()=>void;saved:(notice:string)=>void
}){
  const id=useId(),[base,setBase]=useState<number|null>(null)
  const m=useFinDecision(api,'learning:'+term+':'+goal.id+':progress',{progress:''})
  const stale=base!==null&&base!==goal.version
  async function update(retry=false){
    const value=Number(m.fields.progress)
    if(!retry&&(stale||base===null||!m.fields.progress||!Number.isInteger(value)||value<0||value>100))return
    const result=await m.run(retry?undefined:{kind:'goal',term,id:goal.id,version:base!,title:goal.title,category:goal.category,
      target:goal.target,progress:value})
    if(result){setBase(null);saved('Progress saved.')}else refresh()
  }
  return <div className="goal-progress" data-pending-command={m.locked} data-unsaved-changes={base!==null}>
    {m.error?<p role="alert">{m.error}</p>:null}
    <Retry busy={m.busy||checking} pending={!!m.pending} retry={()=>void update(true)}/>
    {stale&&!m.pending?<p role="alert">The goal changed. <button className="button button--secondary" disabled={checking}
      onClick={()=>{setBase(goal.version);m.change(m.fields)}}>Keep progress and review latest</button></p>:null}
    <form className="growth-inline" onSubmit={event=>{event.preventDefault();void update()}}>
      <TextField id={id} type="number" label={'Progress for '+goal.title+' (%)'} min={0} max={100}
        disabled={checking||m.locked||stale} value={base===null?String(goal.progress):m.fields.progress}
        onChange={event=>{setBase(v=>v??goal.version);m.change({progress:event.target.value})}}/>
      <button className="button button--secondary" disabled={checking||m.locked||stale||base===null}>Save progress</button>
    </form>
  </div>
}
