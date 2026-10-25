import {createContext,useContext,useMemo,useState,useRef,useEffect,Fragment,type ReactNode} from 'react'
import type {FinAuthorityApi,FinCommand} from './authority-api'
type Entry={fields:Record<string,string>;pending:{command:FinCommand;key:string}|null;error:string}
const Context=createContext<Map<string,Entry>|null>(null)
export function FinDecisionMemory({identity,children}:{identity:string;children:ReactNode}){const store=useMemo(()=>new Map<string,Entry>(),[identity]);return <Context.Provider value={store}><Fragment key={identity}>{children}</Fragment></Context.Provider>}
export function useFinDecision(api:FinAuthorityApi,id:string,initial:Record<string,string>){const store=useContext(Context),[entry,setEntry]=useState<Entry>(()=>store?.get(id)??{fields:initial,pending:null,error:''}),[busy,setBusy]=useState(false),live=useRef(true);useEffect(()=>{live.current=true;return()=>{live.current=false}},[]);
 function put(v:Entry){store?.set(id,v);if(live.current)setEntry(v)}
 function change(fields:Record<string,string>){if(!busy&&!entry.pending)put({...entry,fields,error:''})}
 async function run(command?:FinCommand){if(busy)return null;const pending=entry.pending??(command?{command:structuredClone(command),key:crypto.randomUUID()}:null);if(!pending)return null;put({...entry,pending,error:''});setBusy(true);let result;try{result=await api.run(pending.command,pending.key)}catch{result={ok:false as const,error:{message:'The result is uncertain. Retry the identical FIN command.',retryable:true}}}if(!result.ok){put({...entry,pending:result.error.retryable?pending:null,error:result.error.message});if(live.current)setBusy(false);return null}store?.delete(id);if(live.current){setEntry({...entry,pending:null,error:''});setBusy(false)}return result.value}
 return{...entry,change,run,busy,locked:busy||entry.pending!==null}
}
