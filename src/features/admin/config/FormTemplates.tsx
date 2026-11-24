import {useState} from 'react'
import type {FormDefinition} from '../../requests/catalog/api'
import {freshQuestionKey,newQuestion} from './question-factory'

const templates={
 schedule:{label:'Schedule and place',size:2,description:'Optional date and time in Asia/Manila, plus a place or online location.',create:(section:string)=>[
  {...newQuestion('date_time',section),label:'When is it needed?',help:'Leave blank if the schedule is not yet known.'},
  {...newQuestion('short_text',section),label:'Where is it needed?',help:'Name the place or online location. Leave blank if it is not yet known.'}
 ]},
 items:{label:'Items to prepare',size:3,description:'Repeatable item descriptions and quantities. No prices, financial decisions or approval information.',create:(section:string)=>{
  const rows=newQuestion('line_items',section)
  return[{...rows,label:'Items to prepare',help:'Add only the items needed for this request. Money and approvals belong in their protected workflows.',itemFields:[
   {...rows.itemFields![0],label:'Item or activity',help:'Describe the item or activity in this row.',required:true},
   {...newQuestion('number',section),label:'Quantity',help:'Enter the number needed.',required:true,min:1}
  ]}]
 }}
} as const

export function FormTemplates({value,fieldCount,change}:{value:FormDefinition;fieldCount:number;change:(next:FormDefinition)=>void}){
 const[selected,setSelected]=useState<keyof typeof templates>('schedule'),template=templates[selected],blocked=value.sections.length>=10||fieldCount+template.size>50
 function add(){if(blocked)return;const section={key:freshQuestionKey('section'),label:template.label};change({...value,sections:[...value.sections,section],fields:[...value.fields,...template.create(section.key)]})}
 return <details><summary>Templates</summary><p>Add a ready-to-edit question set as a new section in this private draft. Existing questions and answers keep their identities. Choose only what this request needs; nothing is published or migrated by adding a template.</p>
  <label>Question template<select aria-label="Question template" value={selected} onChange={e=>setSelected(e.target.value as keyof typeof templates)}>{Object.entries(templates).map(([key,t])=><option key={key} value={key}>{t.label}</option>)}</select></label>
  <p>{template.description}</p><p>This adds 1 section and {template.size} questions including row children. All use ordinary request access; this template grants no access or approval authority. You can edit or remove unreferenced draft questions before saving.</p>
  {blocked?<p>This template will not fit. Keep the form within 10 sections and 50 total questions including row children. Remove unused draft questions or empty sections first; existing questions are kept.</p>:null}
  <button type="button" className="button button--secondary" disabled={blocked} onClick={add}>Add template questions</button>
 </details>
}
