import {useCallback,useEffect,useMemo,useRef,useState} from 'react'

// In-memory providers register their maps; no private values leave the process.
const stores=new Set<(id:string)=>void>()
export function useDraftStore<T>(identity:string){
 const entry=useMemo(()=>({map:new Map<string,T>()}),[identity]),[,changed]=useState(0)
 useEffect(()=>{
  const forget=(id:string)=>{
   const keys=[...entry.map.keys()].filter(key=>key.split(':').includes(id)||key.length===72&&id.length===36&&key.slice(36)===id)
   if(!keys.length)return
   // Rotate the snapshot, so a late response holding the old map cannot restore revoked data.
   const next=new Map(entry.map);for(const key of keys)next.delete(key);entry.map=next;changed(n=>n+1)
  }
  stores.add(forget);return()=>{stores.delete(forget);entry.map.clear()}
 },[entry])
 return entry.map
}
export function forgetRecordDrafts(id:string){
 if(!id)return
 for(const forget of stores)forget(id)
}
// Only successful authorized reads supply a signature. A transport error is not revocation.
export type RecordAuthority=string|{scope:string;state:string;actions:string}
export const recordAuthority=(state:string,scope:unknown[],actions:unknown[]=[]):RecordAuthority=>({state,scope:JSON.stringify(scope),actions:JSON.stringify(actions)})
export function useRecordAuthority(id:string){
 const previous=useRef<{id:string;signature:Exclude<RecordAuthority,string>|null}|null>(null),[epoch,setEpoch]=useState(0)
 const observe=useCallback((value:RecordAuthority|null)=>{
  const signature=typeof value==='string'?{scope:value,state:'',actions:''}:value
  const old=previous.current
  // A successful command can change available actions before its response reaches the caller.
  // Keep the identical retry through business-state changes; confirmed read loss always clears.
  if(signature===null||old?.id===id&&old.signature&&signature&&(old.signature.scope!==signature.scope||old.signature.state===signature.state&&old.signature.actions!==signature.actions)){forgetRecordDrafts(id);setEpoch(n=>n+1)}
  previous.current={id,signature}
 },[id])
 return {observe,epoch}
}
