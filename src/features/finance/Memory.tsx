import {createContext,useContext,useEffect,useMemo,useRef,useState,Fragment,type ReactNode} from 'react'
import type {PlanDraft} from './intake'
import type {FinanceApi,FinanceSubmission} from './api'
export type FinanceFields={plan:PlanDraft;title:string;requestedOn:string;ack:boolean}
type Entry={fields:FinanceFields;pending:{input:FinanceSubmission;key:string}|null;error:string}
const Context=createContext<Map<string,Entry>|null>(null)
export function FinanceMemory({identity,children}:{identity:string;children:ReactNode}){const store=useMemo(()=>new Map<string,Entry>(),[identity]);return <Context.Provider value={store}><Fragment key={identity}>{children}</Fragment></Context.Provider>}
export function useFinanceMemory(api:FinanceApi,id:string,initial:FinanceFields){const store=useContext(Context),[entry,setEntry]=useState<Entry>(()=>store?.get(id)??{fields:initial,pending:null,error:''}),[busy,setBusy]=useState(false),live=useRef(true);
 useEffect(()=>{live.current=true;return()=>{live.current=false}},[]);
 function put(next:Entry){store?.set(id,next);if(live.current)setEntry(next)}
 function change(fields:FinanceFields){if(!entry.pending&&!busy)put({...entry,fields,error:''})}
 async function run(input?:FinanceSubmission){if(busy)return null;const pending=entry.pending??(input?{input:structuredClone(input),key:crypto.randomUUID()}:null);if(!pending)return null;put({...entry,pending,error:''});setBusy(true);let result;try{result=await api.submit(pending.input,pending.key)}catch{result={ok:false as const,error:{retryable:true,message:'The result is uncertain. Retry the same finance submission.'}}}if(!result.ok){put({...entry,pending:result.error.retryable?pending:null,error:result.error.message});if(live.current)setBusy(false);return null}store?.delete(id);if(live.current){setEntry({...entry,pending:null,error:''});setBusy(false)}return result.value}
 return{...entry,change,run,busy,locked:busy||entry.pending!==null}
}
