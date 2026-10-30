import {useState} from 'react'
import {defaultProposal,externalTemplate,planReminder,type NotificationProposal,type PlannedReminder} from './proposal'
export function ProposalEditor(){
 const[rule,setRule]=useState(defaultProposal),[due,setDue]=useState('2027-04-17'),[rows,setRows]=useState<PlannedReminder[]|null>(null),[error,setError]=useState(''),[dirty,setDirty]=useState(false)
 function change(next:NotificationProposal){setRule(next);setRows(null);setError('');setDirty(true)}
 function preview(){setRows(null);setError('');try{const d=Date.parse(due+'T00:00:00Z');if(!Number.isFinite(d))throw Error();setRows(planReminder(rule,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',due,new Date(d-3*86400000).toISOString(),new Date(d+5*86400000).toISOString()))}catch{setError('Choose a valid example date, whole-number timings and different quiet-hour boundaries. Your proposal is kept.')}}
 const hour=(key:'hour'|'quietStart'|'quietEnd',label:string)=><label>{label}<select className="overview-example" value={rule[key]} onChange={e=>change({...rule,[key]:Number(e.target.value)})}>{Array.from({length:24},(_,h)=><option key={h} value={h}>{String(h).padStart(2,'0')}:00</option>)}</select></label>
 return <details className="work-section" data-edit-form data-unsaved-changes={dirty}><summary>Try notification timing proposals</summary>
 <p>Temporary fictional examples only. Nothing is saved, published, queued or sent. Actual recipient preview and saved-rule publication controls are not available in this editor yet.</p>
 <fieldset><legend>Reminder proposal</legend><p>Events: before due, due day, and overdue. Audience: current assignees with current access, subject to independent server verification before any future delivery.</p>
 <label>Proposed channel<select className="overview-example" value={rule.channel} onChange={e=>change({...rule,channel:e.target.value as NotificationProposal['channel']})}><option value="in_app">In-app</option><option value="email">Email · not connected</option><option value="telegram">Telegram · not connected</option></select></label>
 <label>Optional delivery mode<select className="overview-example" value={rule.mode} onChange={e=>change({...rule,mode:e.target.value as NotificationProposal['mode']})}><option value="immediate">Individual update proposal</option><option value="digest">Grouped digest proposal</option><option value="mute">Mute optional delivery</option></select></label>
 <label>Days before due<input className="overview-example" type="number" min={1} max={7} value={rule.beforeDays} onChange={e=>change({...rule,beforeDays:Number(e.target.value)})}/></label>
 <label><input type="checkbox" checked={rule.dueDay} onChange={e=>change({...rule,dueDay:e.target.checked})}/>Include the due day</label>
 <label>Overdue interval in days<input className="overview-example" type="number" min={1} max={7} value={rule.overdueEveryDays} onChange={e=>change({...rule,overdueEveryDays:Number(e.target.value)})}/></label>
 {hour('hour','Proposed reminder time · Manila')}{hour('quietStart','Quiet hours start · Manila')}{hour('quietEnd','Quiet hours end · Manila')}
 <label>Example due date · Manila<input className="overview-example" type="date" value={due} onChange={e=>{setDue(e.target.value);setDirty(true);setRows(null);setError('')}}/></label>
 </fieldset><p>Quiet hours defer optional external delivery only. Mute and unavailable channels never remove required in-app work. Digest grouping requires the future server scheduler.</p>
 <p>Fixed external wording: {externalTemplate(rule.template)} No private content or custom placeholders can be entered.</p>
 <button className="button button--secondary" onClick={preview}>Preview fictional timing (send nothing)</button>{error?<p role="alert">{error}</p>:null}
 {rows?<section aria-label="Fictional timing preview"><h3>Fictional timing preview</h3><p>No recipient lookup, count, impersonation or send occurs. These are candidate reminders for one fictional task, not actual digest messages. {rule.channel==='in_app'?'In-app proposal; live scheduling remains disabled.':'External channel not connected. Use the in-app work page.'}</p><ol>{rows.map(r=><li key={r.key}>{r.event==='before_due'?'Before due':r.event==='due'?'Due day':'Overdue'} · obligation date {r.logicalDay} · proposed {new Date(r.at).toLocaleString('en-PH',{timeZone:'Asia/Manila'})} Manila{rule.mode==='mute'?' · Optional delivery muted':''}</li>)}</ol><p>Actual work and existing in-app updates remain authoritative.</p></section>:null}
 </details>
}
