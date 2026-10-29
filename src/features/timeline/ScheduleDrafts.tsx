import {useDraftStore} from '../auth/draftScope'
import {createContext,useContext,Fragment,type ReactNode} from 'react'
import type {ScheduleContext} from './api'
export type ScheduleDraft={value:string;base:ScheduleContext;pending:{start:string|null;version:number;key:string}|null}
const DraftContext=createContext<Map<string,ScheduleDraft>|null>(null)
// Only dates/versions/retry keys; memory survives a routine access check, never an identity change.
export function ScheduleDrafts({identity,children}:{identity:string;children:ReactNode}){
 const drafts=useDraftStore<ScheduleDraft>(identity)
 return <DraftContext.Provider value={drafts}><Fragment key={identity}>{children}</Fragment></DraftContext.Provider>
}
export function useScheduleDrafts(){return useContext(DraftContext)}
