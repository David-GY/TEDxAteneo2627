import {describe,it,expect,vi,afterEach} from 'vitest'
import {render,screen,fireEvent,waitFor,cleanup} from '@testing-library/react'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {Files} from './Files'
import type {FilesApi,FilesPage} from './api'
import {mapCommandError} from '../../lib/commands'
afterEach(cleanup)
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',assetId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
const empty:FilesPage={assets:[],manifests:[],workVersion:1,canEdit:true}
function api():FilesApi{return{read:vi.fn().mockResolvedValue(empty),execute:vi.fn().mockResolvedValue({ok:true,value:{assetId,version:1}}),download:vi.fn(),open:vi.fn()}}
function show(a:FilesApi){render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/',loader:()=>({memberId:'actor'}),Component:()=> <Files api={a} workId={id}/>}])}/>)}
describe('P12 file editor',()=>{
 it('keeps denied metadata hidden',async()=>{const a=api();vi.mocked(a.read).mockResolvedValue(null);show(a);await screen.findByText('Files are not shared');expect(screen.queryByLabelText('PDF, JPEG or PNG file')).toBeNull()})
 it('retains exact source payload/key after unconfirmed response',async()=>{const a=api();vi.mocked(a.execute).mockResolvedValueOnce({ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})});show(a);await screen.findByLabelText('Working source URL (required for saving a source)');fireEvent.change(screen.getByLabelText('Working source URL (required for saving a source)'),{target:{value:'https://docs.google.com/document/d/Fictional/edit?x=1'}});fireEvent.change(screen.getByLabelText('Source name (required for saving a source)'),{target:{value:'Fictional source'}});fireEvent.change(screen.getByLabelText('Owner and access notes (required for saving a source)'),{target:{value:'Synthetic notes'}});fireEvent.change(screen.getByLabelText('Source version or export label (required for saving a source)'),{target:{value:'v1'}});fireEvent.click(screen.getByRole('button',{name:'Save working source'}));fireEvent.click(await screen.findByRole('button',{name:'Retry same file request'}));await waitFor(()=>expect(a.execute).toHaveBeenCalledTimes(2));expect(vi.mocked(a.execute).mock.calls[0]).toEqual(vi.mocked(a.execute).mock.calls[1])})
})
