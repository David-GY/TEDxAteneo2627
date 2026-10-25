import type {FormDefinition} from '../requests/catalog/api'
export const definition:FormDefinition={schemaVersion:1,sections:[{key:'need',label:'Support need'}],fields:[
 {key:'detail_needed',section:'need',label:'Need extra detail?',help:'Choose whether detail is needed.',classification:'ordinary',type:'single_choice',required:true,options:[{id:'yes',label:'Yes'},{id:'no',label:'No'}]},
 {key:'detail',section:'need',label:'Extra detail',help:'Explain the need.',classification:'ordinary',type:'short_text',required:false,visibleWhen:{op:'eq',field:'detail_needed',value:'yes'},requiredWhen:{op:'eq',field:'detail_needed',value:'yes'}},
]}
