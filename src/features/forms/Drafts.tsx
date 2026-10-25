import {createContext,useContext,useMemo,Fragment,type ReactNode} from 'react'
import type {FormValues} from './validation'
export type FormDraft={values:FormValues;money:string}
const Context=createContext<Map<string,FormDraft>|null>(null)
export function FormDrafts({identity,children}:{identity:string;children:ReactNode}){const drafts=useMemo(()=>new Map<string,FormDraft>(),[identity]);return <Context.Provider value={drafts}><Fragment key={identity}>{children}</Fragment></Context.Provider>}
export function useFormDrafts(){return useContext(Context)}
