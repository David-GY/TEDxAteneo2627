import {fireEvent,render,screen} from '@testing-library/react'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {expect,it,vi} from 'vitest'
import {RequestDetailPage} from './RequestPages'
import {RequestMemory,useRequestMemory} from './Memory'
import {FormDrafts} from '../forms/Drafts'
import {definition} from '../forms/form.test-data'
import type {RequestsApi,RequestView} from './api'

it('P35_U2: confirmed request scope loss clears only that record; reconnect cannot resurrect private inputs',async()=>{
 const record:RequestView={id:'record-a',termId:'term',title:'Saved title',version:1,typeId:'type',typeLabel:'Fictional service',serviceLabel:'Fictional receiving team',state:'draft',revision:0,trackingId:null,originalRequestedOn:null,acceptedOn:null,formVersionId:'form',formVersion:1,workflowVersionId:'workflow',workflowVersion:1,form:definition,classification:'restricted',canEdit:true,canSubmit:true,canRevise:false,canCancel:false,nextAction:'Complete your saved draft.',draft:{values:{detail_needed:'yes',detail:'Saved detail'},snapshots:{},requestedCentavos:null,requestedOn:null},selected:null,revisionHeaders:[],history:{page:1,pageSize:25,total:0,items:[]}}
 let value:RequestView|null=record,failed=false
 const api:RequestsApi={read:vi.fn(async()=>{if(failed)throw Error('Offline');return value}),list:vi.fn(),run:vi.fn()}
 function OtherDraft(){const m=useRequestMemory(api,'record-b',{note:''});return <input aria-label="Other record note" value={m.fields.note} onChange={e=>m.change({note:e.target.value})}/>}
 const router=createMemoryRouter([{id:'workspace',loader:()=>({termId:'term',memberId:'member'}),path:'/requests/:requestTermId/:requestId',element:<RequestMemory identity="account"><FormDrafts identity="account"><OtherDraft/><RequestDetailPage api={api} forms={{options:vi.fn(async()=>({members:[],units:[],files:[]}))} as never}/></FormDrafts></RequestMemory>}],{initialEntries:['/requests/term/record-a']})
 render(<RouterProvider router={router}/>);
 const detail=await screen.findByLabelText('Extra detail (required)');fireEvent.change(detail,{target:{value:'Private unsaved detail'}})
 fireEvent.change(screen.getByLabelText('Private request title (required)'),{target:{value:'Private unsaved title'}})
 fireEvent.change(screen.getByLabelText('Other record note'),{target:{value:'Keep unrelated work'}})
 const refresh=()=>fireEvent.click(screen.getByRole('button',{name:'Refresh request (keep inputs)'}))
 failed=true;refresh();await screen.findByText('Request unavailable');failed=false;refresh()
 expect((await screen.findByLabelText('Extra detail (required)') as HTMLInputElement).value).toBe('Private unsaved detail')
 value=null;refresh();await screen.findByText('Request cannot be shown');value=record;refresh()
 expect((await screen.findByLabelText('Extra detail (required)') as HTMLInputElement).value).toBe('Saved detail')
 expect((screen.getByLabelText('Private request title (required)') as HTMLInputElement).value).toBe('Saved title')
 expect((screen.getByLabelText('Other record note') as HTMLInputElement).value).toBe('Keep unrelated work')
 fireEvent.change(screen.getByLabelText('Extra detail (required)'),{target:{value:'Clear on edit-scope downgrade'}})
 value={...record,canEdit:false};refresh();await screen.findByText('Saved draft · read only');value=record;refresh()
 expect((await screen.findByLabelText('Extra detail (required)') as HTMLInputElement).value).toBe('Saved detail')
})
