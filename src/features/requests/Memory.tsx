import {useDraftStore} from '../auth/draftScope'
import {createContext,useContext,useRef,useEffect,useState,Fragment,type ReactNode} from 'react'
import type {RequestCommand,RequestReceipt,RequestsApi} from './api'
type Pending={command:RequestCommand;key:string}
type Draft={fields:Record<string,string>;pending:Pending|null}
const Context=createContext<Map<string,Draft>|null>(null)
export function RequestMemory({identity,children}:{identity:string;children:ReactNode}){const drafts=useDraftStore<Draft>(identity);return <Context.Provider value={drafts}><Fragment key={identity}>{children}</Fragment></Context.Provider>}
export function useRequestMemory(api:RequestsApi,id:string,initial:Record<string,string>){
 const memory=useContext(Context),[fields,setFields]=useState(()=>memory?.get(id)?.fields??initial),[pending,setPending]=useState<Pending|null>(()=>memory?.get(id)?.pending??null),[busy,setBusy]=useState(false),[error,setError]=useState(''),live=useRef(true);
 useEffect(()=>{live.current=true;return()=>{live.current=false}},[]);
 function change(next:Record<string,string>){setFields(next);memory?.set(id,{fields:next,pending});setError('')}
 async function run(command?:RequestCommand):Promise<RequestReceipt|null>{if(busy)return null;const attempt=pending??(command?{command:structuredClone(command),key:crypto.randomUUID()}:null);if(!attempt)return null;
  setPending(attempt);memory?.set(id,{fields,pending:attempt});setBusy(true);setError('');const result=await api.run(attempt.command,attempt.key);if(!live.current)return null;setBusy(false);
  if(!result.ok){setError(result.error.message);if(!result.error.retryable){setPending(null);memory?.set(id,{fields,pending:null})}return null}
  setPending(null);memory?.delete(id);return result.value;
 }
 return{fields,change,pending,busy,error,locked:pending!==null||busy,run};
}
