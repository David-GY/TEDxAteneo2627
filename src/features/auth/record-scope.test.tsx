import {fireEvent,render,screen,waitFor} from '@testing-library/react'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {expect,it,vi} from 'vitest'
import {CurrentRecordScope} from './RecordScope'
import {AuthRevalidator} from './pages'
import type {AuthGateway} from './gateway'
import {useRequestMemory} from '../requests/Memory'
import type {RequestsApi} from '../requests/api'
import {RecordScope} from './RecordScope'
import {HandoffDrafts,useHandoffDrafts} from '../handoffs/Drafts'
import {forgetRecordDrafts} from './draftScope'

it('P35_U2: record checks pause mounted edits, preserve them on connection error, and clear only revoked scope on recovery',async()=>{
 let access:{canEdit:boolean;canManage:boolean}|null={canEdit:true,canManage:false},offline=false
 const gateway={onChange:()=>()=>{},tasks:{detail:vi.fn(async()=>{if(offline)throw Error('Offline');return access})}} as unknown as AuthGateway
 const api={} as RequestsApi
 function Work(){const own=useRequestMemory(api,'record-a',{note:'Server note'}),other=useRequestMemory(api,'record-b',{note:''});return <><input aria-label="Record note" value={own.fields.note} onChange={e=>own.change({note:e.target.value})}/><input aria-label="Other note" value={other.fields.note} onChange={e=>other.change({note:e.target.value})}/></>}
 const router=createMemoryRouter([{element:<AuthRevalidator gateway={gateway}/>,children:[{id:'workspace',path:'/tasks/:taskId',loader:()=>({termId:'term',memberId:'member',capabilities:['workspace.read']}),element:<CurrentRecordScope gateway={gateway}><Work/></CurrentRecordScope>}]}],{initialEntries:['/tasks/record-a']})
 render(<RouterProvider router={router}/>);await waitFor(()=>expect(screen.getByLabelText('Record note').closest('[inert]')).toBeNull())
 fireEvent.change(screen.getByLabelText('Record note'),{target:{value:'Private working note'}});fireEvent.change(screen.getByLabelText('Other note'),{target:{value:'Unrelated working note'}})
 offline=true;fireEvent.focus(window);await screen.findByText('Record access could not be checked. Your inputs are kept; reconnect and check again.')
 expect((screen.getByLabelText('Record note') as HTMLInputElement).value).toBe('Private working note')
 offline=false;fireEvent.focus(window);await waitFor(()=>expect(screen.getByLabelText('Record note').closest('[inert]')).toBeNull())
 expect((screen.getByLabelText('Record note') as HTMLInputElement).value).toBe('Private working note')
 access=null;fireEvent.focus(window);await screen.findByText('This record is unavailable to your current account. Its private drafts have been cleared.');expect(screen.queryByLabelText('Record note')).toBeNull()
 access={canEdit:true,canManage:false};fireEvent.focus(window)
 expect((await screen.findByLabelText('Record note') as HTMLInputElement).value).toBe('Server note');expect((screen.getByLabelText('Other note') as HTMLInputElement).value).toBe('Unrelated working note')
 fireEvent.change(screen.getByLabelText('Record note'),{target:{value:'Lost editing authority'}});access={canEdit:false,canManage:false};fireEvent.focus(window)
 await waitFor(()=>expect((screen.getByLabelText('Record note') as HTMLInputElement).value).toBe('Server note'))
})

it('P35_U2: a late response from a revoked handoff form cannot restore its old private draft or erase unrelated drafts',async()=>{
 let allowed=true,late:(()=>void)|undefined
 function Work(){const store=useHandoffDrafts()!,key='send:record-a:new';return <><input aria-label="Scoped handoff note" defaultValue={store.get(key)?.fields.note??'Server note'} onChange={e=>{const draft={fields:{note:e.target.value},pending:null};store.set(key,draft);late=()=>store.set(key,draft)}}/><input aria-label="Unrelated handoff note" defaultValue={store.get('send:record-ab:new')?.fields.note??''} onChange={e=>store.set('send:record-ab:new',{fields:{note:e.target.value},pending:null})}/></>}
 const view=(key:string)=><HandoffDrafts identity="late-scope"><RecordScope id="record-a" read={async()=>allowed?'editable':null}><Work key={key}/></RecordScope></HandoffDrafts>
 const {rerender}=render(view('initial'))
 fireEvent.change(await screen.findByLabelText('Scoped handoff note'),{target:{value:'Private pending note'}});fireEvent.change(screen.getByLabelText('Unrelated handoff note'),{target:{value:'Keep separate work'}})
 allowed=false;fireEvent.focus(window);await screen.findByText('This record is unavailable to your current account. Its private drafts have been cleared.')
 allowed=true;fireEvent.focus(window)
 await waitFor(()=>expect((screen.getByLabelText('Scoped handoff note') as HTMLInputElement).value).toBe('Server note'))
 late!();rerender(view('reopened'))
 expect((screen.getByLabelText('Scoped handoff note') as HTMLInputElement).value).toBe('Server note')
 forgetRecordDrafts('record');rerender(view('another-open'))
 expect((screen.getByLabelText('Unrelated handoff note') as HTMLInputElement).value).toBe('Keep separate work')
})
