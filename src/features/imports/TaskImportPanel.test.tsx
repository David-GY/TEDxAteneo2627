import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react'
import {afterEach,expect,it,vi} from 'vitest'
import {MemoryRouter} from 'react-router'
import {TaskImportPanel} from './TaskImportPanel'
import {ImportError,type TaskImportsApi,type ImportPreview,type ImportReceipt} from './task-import-api'
afterEach(cleanup)
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',term='22222222-2222-4222-8222-222222222221'
const input={header:['source_key','title'],mapping:{source_key:'source_key',title:'title'},rows:[['one','Prepare signage']]}
const preview={draftId:id,version:1,listName:'Venue',unitName:'Venue committee',valid:true,reviewHash:'a'.repeat(64),rows:[{record:2,sourceKey:'one',operation:'create',targetId:null,reference:null,expectedWorkVersion:null,assigneeId:id,before:null,after:{title:'Prepare signage',assignee:'Fictional River',dueOn:null,dueAt:null},errors:[]}]}as ImportPreview
const receipt={draftId:id,version:2,state:'committed',created:1,updated:0,unchanged:0,items:[{sourceKey:'one',workItemId:id,title:'Prepare signage',reference:'TASK-027',version:1,action:'create',href:'/tasks/'+id+'?term='+term}]}as ImportReceipt
it('resuming semantically identical saved JSON does not require another save because object keys were reordered by the server',async()=>{
 const saved={draftId:id,version:1,state:'draft' as const,listName:'Venue'}
 const api:TaskImportsApi={read:async(_term,key)=>({units:[{id,name:'Venue committee'}],drafts:[saved],draft:key?{...saved,unitId:id,input:{rows:input.rows,mapping:input.mapping,header:input.header},receipt:null}:null}),save:async()=>saved,preview:async()=>preview,commit:async()=>receipt}
 render(<MemoryRouter><TaskImportPanel api={api} term={term} input={input} enabled onLoad={()=>{}} onDenied={()=>{}} onLockChange={()=>{}}/></MemoryRouter>)
 await screen.findByRole('option',{name:'Venue · draft · version 1'});fireEvent.click(screen.getByText('Resume or recheck a private server draft'));fireEvent.change(screen.getByLabelText('Saved draft'),{target:{value:id}});fireEvent.click(screen.getByRole('button',{name:'Replace input with selected saved draft'}))
 await waitFor(()=>expect((screen.getByRole('button',{name:'Preview server changes'}) as HTMLButtonElement).disabled).toBe(false))
})
it('P45_U1 unknown commit outcome locks edits and retries the same key/hash; receipt and issued reference replace confirmation',async()=>{
 const keys:string[]=[],lock=vi.fn(),api:TaskImportsApi={read:async()=>({units:[{id,name:'Venue committee'}],drafts:[],draft:null}),save:async()=>({draftId:id,version:1,state:'draft'}),preview:async()=>preview,commit:async(_term,_id,_version,hash,key)=>{expect(hash).toBe(preview.reviewHash);keys.push(key);if(keys.length===1)throw new ImportError('connection');return receipt}}
 render(<MemoryRouter><TaskImportPanel api={api} term={term} input={input} enabled onLoad={()=>{}} onDenied={()=>{}} onLockChange={lock}/></MemoryRouter>)
 await screen.findByRole('option',{name:'Venue committee'});fireEvent.change(screen.getByLabelText('Import committee'),{target:{value:id}});fireEvent.change(screen.getByLabelText('List name (reuse for retries)'),{target:{value:'Venue'}})
 fireEvent.click(screen.getByRole('button',{name:'Save private task draft'}));await screen.findByText('Private task draft saved. Preview current server changes before importing.')
 fireEvent.click(screen.getByRole('button',{name:'Preview server changes'}));await screen.findByText('Fictional River')
 const commit=screen.getByRole('button',{name:'Import reviewed tasks'});expect((commit as HTMLButtonElement).disabled).toBe(true)
 fireEvent.click(screen.getByLabelText('I reviewed these exact task changes.'));fireEvent.click(commit);await screen.findByRole('button',{name:'Retry identical request'})
 expect((screen.getByLabelText('List name (reuse for retries)') as HTMLInputElement).disabled).toBe(true)
 fireEvent.click(screen.getByRole('button',{name:'Retry identical request'}));const link=await screen.findByRole('link',{name:'Prepare signage · TASK-027'});expect(link.getAttribute('href')).toBe('/tasks/'+id+'?term='+term);expect(keys).toHaveLength(2);expect(keys[1]).toBe(keys[0]);expect(screen.queryByRole('button',{name:'Import reviewed tasks'})).toBeNull();expect(lock).toHaveBeenLastCalledWith(false)
})
