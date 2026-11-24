import {useEffect,useRef,type ReactNode} from 'react'
import {useBlocker} from 'react-router'

// Guard deliberate work editors only; no draft values enter browser storage.
export function EditSafety({children}:{children:ReactNode}){
 const root=useRef<HTMLDivElement>(null),dirty=useRef(new WeakSet<Element>())
 const pending=()=>!!root.current?.querySelector('[data-pending-command="true"]')
 const unsaved=()=>Array.from(root.current?.querySelectorAll('[data-edit-form]')??[]).some(form=>dirty.current.has(form))||!!root.current?.querySelector('[data-unsaved-changes="true"]')
 const blocker=useBlocker(()=>unsaved()||pending())
 useEffect(()=>{const warn=(event:BeforeUnloadEvent)=>{if(unsaved()||pending()){event.preventDefault();event.returnValue=''}};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn)},[])
 useEffect(()=>{
  const container=root.current
  const saved=(event:Event)=>{if(event.target instanceof Element)dirty.current.delete(event.target)}
  container?.addEventListener('workspace-edit-saved',saved)
  return()=>container?.removeEventListener('workspace-edit-saved',saved)
 },[])
 function changed(target:EventTarget|null){
  const form=target instanceof Element?target.closest('[data-edit-form]'):null
  if(form)dirty.current.add(form)
 }
 return <div ref={root} onChangeCapture={e=>changed(e.target)} onInputCapture={e=>changed(e.target)} onClickCapture={e=>{
  if(!(e.target instanceof Element)||!e.target.closest('[data-discard-edits]'))return
  if(pending()||unsaved()&&!window.confirm('Discard unsaved edits and refresh this work?')){e.preventDefault();e.stopPropagation();return}
  dirty.current=new WeakSet()
 }}>
 {blocker.state==='blocked'?<section className="panel" role="alert" aria-label="Keep your unsaved work"><h2>{pending()?'Check whether saved before leaving':'Leave your unsaved work?'}</h2><p>{pending()?'A command is still being checked. Keep this page open and retry the same command; creating a new attempt could repeat the action.':'Your entered work may be discarded. Keep editing or explicitly discard it before leaving.'}</p><div className="auth-actions"><button className="button" onClick={()=>blocker.reset()}>Keep editing</button>{!pending()?<button className="button button--secondary" onClick={()=>{dirty.current=new WeakSet();blocker.proceed()}}>Discard edits and leave</button>:null}</div></section>:null}
 {children}
 </div>
}
