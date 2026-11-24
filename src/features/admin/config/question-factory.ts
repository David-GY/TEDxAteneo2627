import type {FormField} from '../../requests/catalog/api'
export const ordinaryQuestionTypes={short_text:'Short answer',long_text:'Long answer',number:'Number',date:'Date',date_time:'Date and time',single_choice:'Choose one',multi_choice:'Choose several',checkbox:'Checkbox',member:'Named member',unit:'Named committee',url:'HTTPS link',file:'Finalized files'} as const
export type OrdinaryQuestionType=keyof typeof ordinaryQuestionTypes
export type NewQuestionType=OrdinaryQuestionType|'line_items'
export const freshQuestionKey=(prefix:string)=>prefix+'_'+crypto.randomUUID().replaceAll('-','')
export function newQuestion(type:NewQuestionType,section:string):FormField{
 const f:FormField={key:freshQuestionKey('field'),section,label:'New question',help:'',type,required:false,classification:'ordinary'}
 if(['short_text','long_text','url'].includes(type))f.maxLength=type==='long_text'?2000:type==='url'?2048:240
 if(type==='single_choice'||type==='multi_choice')f.options=[{id:freshQuestionKey('option'),label:'First choice'}]
 if(type==='file'||type==='multi_choice')f.maxItems=5
 if(type==='line_items'){f.maxItems=10;f.itemFields=[{...newQuestion('short_text',section),label:'Row detail'}]}
 return f
}
