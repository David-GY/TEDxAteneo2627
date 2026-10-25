import {createContext,useContext,useMemo,useRef,useEffect,useState,Fragment,type ReactNode} from 'react'
import type {ApprovalsApi,ActivateWorkflow,TransitionRequest} from './api'
import type {InboxApi,TriageInput} from './inbox-api'
export type ReviewCommand={kind:'activate';input:ActivateWorkflow}|{kind:'transition';input:TransitionRequest}|{kind:'triage';input:TriageInput}
type Draft={fields:Record<string,string>;pending:ReviewCommand|null}
const Context=createContext<Map<string,Draft>|null>(null)
export function ReviewMemory({identity,children}:{identity:string;children:ReactNode}){const memory=useMemo(()=>new Map<string,Draft>(),[identity]);return <Context.Provider value={memory}><Fragment key={identity}>{children}</Fragment></Context.Provider>}
export function useReviewMemory(id:string,approvals:ApprovalsApi,inbox:InboxApi){
 const memory=useContext(Context),[fields,setFields]=useState<Record<string,string>>(()=>memory?.get(id)?.fields??{reason:'',reviewers:'',acceptedOn:'',evidence:''}),[pending,setPending]=useState<ReviewCommand|null>(()=>memory?.get(id)?.pending??null),[busy,setBusy]=useState(false),[error,setError]=useState(''),live=useRef(true),running=useRef(false)
 useEffect(()=>{live.current=true;return()=>{live.current=false}},[])
 function change(next:Record<string,string>){if(pending||running.current)return;setFields(next);memory?.set(id,{fields:next,pending:null});setError('')}
 async function run(command?:ReviewCommand){if(running.current)return null;const attempt=pending??(command?structuredClone(command):null);if(!attempt)return null;running.current=true;setPending(attempt);memory?.set(id,{fields,pending:attempt});setBusy(true);setError('')
  const result=await(attempt.kind==='activate'?approvals.activate(attempt.input):attempt.kind==='transition'?approvals.transition(attempt.input):inbox.triage(attempt.input));running.current=false;if(!live.current)return null;setBusy(false)
  if(!result.ok){setError(result.error.message);if(!result.error.retryable){setPending(null);memory?.set(id,{fields,pending:null})}return null}
  setPending(null);memory?.set(id,{fields,pending:null});return result.value
 }
 return{fields,change,pending,busy,error,locked:pending!==null||busy,run}
}
