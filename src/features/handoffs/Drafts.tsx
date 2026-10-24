import {createContext,useContext,useMemo,Fragment,type ReactNode} from 'react'
import type {SubmitHandoff,RespondHandoff,AcceptHandoff} from './api'
export type Request={kind:'submit';input:SubmitHandoff}|{kind:'respond';input:RespondHandoff}|{kind:'accept';input:AcceptHandoff}
type Draft={fields:Record<string,string>;pending:Request|null}
const Context=createContext<Map<string,Draft>|null>(null)
export function HandoffDrafts({identity,children}:{identity:string;children:ReactNode}){const drafts=useMemo(()=>new Map<string,Draft>(),[identity]);return <Context.Provider value={drafts}><Fragment key={identity}>{children}</Fragment></Context.Provider>}
export function useHandoffDrafts(){return useContext(Context)}
