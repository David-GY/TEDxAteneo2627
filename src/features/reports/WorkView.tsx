import{useEffect,useRef}from'react'
// Explicit page opening only. Permission polling never resets this page-local flag.
export function WorkView({allowed,record}:{allowed:boolean;record?:()=>Promise<void>}){
 const recorded=useRef(false)
 useEffect(()=>{if(!allowed||!record)return;const opened=()=>{if(!recorded.current&&document.visibilityState==='visible'){recorded.current=true;void record().catch(()=>{})}};opened();document.addEventListener('visibilitychange',opened);return()=>document.removeEventListener('visibilitychange',opened)},[allowed,record])
 return null
}
