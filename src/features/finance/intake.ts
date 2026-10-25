import {parsePhp,lineTotal,sumCentavos,forecastRevenue} from './money'
import {validDate} from '../forms/validation'
export type PlanKind='cost'|'budget'|'expense'|'reimbursement'|'fundraising'|'sales'
export type PlanDraft={kind:PlanKind;purpose:string;fundSource:string;beneficiaryMemberId:string;relatedDeliverableId:string;plannedOn:string;termsRisks:string;price:string;forecastQuantity:string;lines:{description:string;quantity:string;amount:string}[]}
export type FinancePayload={schemaVersion:1;currency:'PHP';kind:PlanKind;purpose:string;fundSource:string;beneficiaryMemberId:string;relatedDeliverableId:string|null;plannedOn:string|null;termsRisks:string;requestedTotalCentavos:string;lines:{description:string;quantity:string;unitAmountCentavos:string;totalCentavos:string}[];pricing?:{unitPriceCentavos:string;forecastQuantity:string;forecastRevenueCentavos:string}}
export const emptyPlan=(member:string):PlanDraft=>({kind:'cost',purpose:'',fundSource:'',beneficiaryMemberId:member,relatedDeliverableId:'',plannedOn:'',termsRisks:'',price:'',forecastQuantity:'',lines:[{description:'',quantity:'1',amount:''}]})
export function phpText(cents:string){const n=BigInt(cents);return(n/100n).toString()+'.'+(n%100n).toString().padStart(2,'0')}
export const showPhp=(cents:string)=>'₱'+phpText(cents).replace(/\B(?=(\d{3})+\.)/g,',')
export function quantityText(milli:number){return(BigInt(milli)/1000n).toString()+'.'+(BigInt(milli)%1000n).toString().padStart(3,'0')}
export function calculatePlan(d:PlanDraft){
 const errors:Record<string,string>={};const rows:FinancePayload['lines']=[];let total:string|null=null,revenue:string|null=null;
 for(const [key,max]of [['purpose',2000],['fundSource',500],['termsRisks',4000]]as const)if(!d[key].trim()||d[key].length>max)errors[key]='Enter a nonblank value within '+max+' characters.'
 if(!/^[0-9a-f-]{36}$/i.test(d.beneficiaryMemberId))errors.beneficiaryMemberId='Choose a current beneficiary.'
 if(d.plannedOn&&!validDate(d.plannedOn))errors.plannedOn='Use a valid date.'
 if(!d.lines.length||d.lines.length>100)errors.lines='Use between 1 and 100 itemized lines.'
 d.lines.forEach((l,i)=>{const k='lines.'+i;let cents:string|undefined,amount:string|undefined;
  if(!l.description.trim()||l.description.length>500)errors[k+'.description']='Describe this item within 500 characters.'
  try{cents=parsePhp(l.amount)}catch{errors[k+'.amount']='Use nonnegative PHP with at most two decimal places.'}
  try{lineTotal(l.quantity,'0')}catch{errors[k+'.quantity']='Use a quantity from 0.001 to 1000000, at most three decimal places.'}
  if(cents!==undefined&&!errors[k+'.quantity'])try{amount=lineTotal(l.quantity,cents)}catch{errors[k+'.amount']='This line exceeds the supported amount range.'}
  if(amount!==undefined&&cents!==undefined)rows.push({description:l.description,quantity:l.quantity,unitAmountCentavos:cents,totalCentavos:amount})
 });
 if(rows.length===d.lines.length)try{total=sumCentavos(rows.map(l=>l.totalCentavos))}catch{errors.lines='The total exceeds the supported amount range.'}
 let pricing:FinancePayload['pricing'];if(d.kind==='fundraising'||d.kind==='sales'){
  let price:string|undefined;try{price=parsePhp(d.price)}catch{errors.price='Use a nonnegative PHP unit price.'}
  try{forecastRevenue(d.forecastQuantity,'0')}catch{errors.forecastQuantity='Use a forecast from 0 to 1000000 with at most three decimal places.'}
  if(price!==undefined&&!errors.forecastQuantity)try{revenue=forecastRevenue(d.forecastQuantity,price);pricing={unitPriceCentavos:price,forecastQuantity:d.forecastQuantity,forecastRevenueCentavos:revenue}}catch{errors.price='Forecast revenue exceeds the supported amount range.'}
 }
 const payload:FinancePayload|null=Object.keys(errors).length||total===null?null:{schemaVersion:1,currency:'PHP',kind:d.kind,purpose:d.purpose,fundSource:d.fundSource,beneficiaryMemberId:d.beneficiaryMemberId,relatedDeliverableId:d.relatedDeliverableId||null,plannedOn:d.plannedOn||null,termsRisks:d.termsRisks,requestedTotalCentavos:total,lines:rows,...(pricing?{pricing}:{})};
 return{payload,errors,total,revenue,lineTotals:d.lines.map(l=>{try{return lineTotal(l.quantity,parsePhp(l.amount))}catch{return null}})}
}
