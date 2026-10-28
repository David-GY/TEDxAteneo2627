import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { expect, it, vi } from 'vitest'
import { DeliverableEditor } from './DeliverableEditor'
import { createDeliverableCommands, type AuthoringContext, type DeliverableCommands } from './commands'
import { mapCommandError } from '../../lib/commands'
import type { createSupabaseClient } from '../../lib/supabase'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
const context:AuthoringContext={memberId:id,version:3,criteriaRevision:2,state:'draft',manager:false,editable:true,actions:['start','submit'],owners:[{id,name:'Fictional owner'}],units:[{id,name:'Fictional unit',canManage:false}],queue:[],data:{title:'Fictional output',summary:'Safe summary',body:'Working notes',ownerId:id,leadUnitId:id,phase:'Preparation',outcome:'Fictional outcome',criteria:'Reviewed checklist',dueOn:'2027-04-10',dueAt:null,classification:'restricted',reason:''}}
function setup(api:DeliverableCommands,existing=true){const saved=vi.fn();render(<MemoryRouter><DeliverableEditor api={api} termId={id} id={existing?id:undefined} onSaved={saved}/></MemoryRouter>);return saved}
it('P09_A2: uncertain edit freezes fields and retries the same payload/key before confirming',async()=>{
  const execute=vi.fn().mockResolvedValueOnce({ok:false,error:mapCommandError({code:'ETIMEDOUT'})}).mockResolvedValueOnce({ok:true,value:{workItemId:id,version:4}})
  const saved=setup({read:async()=>context,execute})
  await screen.findByLabelText('Title (required)')
  fireEvent.change(screen.getByLabelText('Title (required)'),{target:{value:'My revised output'}})
  fireEvent.change(screen.getByLabelText('Reason for this change (required)'),{target:{value:'Deadline and wording clarified'}})
  fireEvent.click(screen.getByRole('button',{name:'Save deliverable'}))
  await screen.findByRole('button',{name:'Retry same request'})
  expect(screen.getByLabelText('Title (required)').matches(':disabled')).toBe(true)
  expect(saved).not.toHaveBeenCalled()
  fireEvent.click(screen.getByRole('button',{name:'Retry same request'}))
  await waitFor(()=>expect(saved).toHaveBeenCalledWith(id))
  expect(execute.mock.calls[0]).toEqual(execute.mock.calls[1])
  expect(execute.mock.calls[0][0]).toMatchObject({command:'update',version:3,data:{title:'My revised output',reason:'Deadline and wording clarified'}})
})
it('P09 stale edit keeps unsaved values and exposes explicit reload rather than showing success',async()=>{
  const saved=setup({read:async()=>context,execute:async()=>({ok:false,error:mapCommandError({code:'40001'})})})
  await screen.findByLabelText('Title (required)')
  fireEvent.change(screen.getByLabelText('Title (required)'),{target:{value:'Unsaved user wording'}})
  fireEvent.change(screen.getByLabelText('Reason for this change (required)'),{target:{value:'Correct wording'}})
  fireEvent.click(screen.getByRole('button',{name:'Save deliverable'}))
  await screen.findByRole('alert')
  expect((screen.getByLabelText('Title (required)') as HTMLInputElement).value).toBe('Unsaved user wording')
  expect(screen.getByRole('button',{name:'Reload latest (discard unsaved edits)'}).matches(':disabled')).toBe(false)
  expect(saved).not.toHaveBeenCalled()
})
it('P09_A1: ordinary create form proposes only the authenticated member',async()=>{
  const execute=vi.fn<DeliverableCommands['execute']>().mockResolvedValue({ok:true,value:{workItemId:id,version:1}})
  setup({read:async()=>({...context,data:null,state:null,version:null,criteriaRevision:null,actions:[]}),execute},false)
  fireEvent.click(screen.getByText('Create or propose a deliverable'))
  await screen.findByLabelText('Title (required)')
  expect(screen.getByLabelText('Accountable owner (required)').matches(':disabled')).toBe(true)
  for(const [label,value] of [['Title (required)','My proposal'],['Phase (required)','Preparation'],['Target date · Manila (required)','2027-04-11'],['Outcome (required)','Team checklist'],['Acceptance criteria (required)','Checklist reviewed']])fireEvent.change(screen.getByLabelText(label),{target:{value}})
  fireEvent.click(screen.getByRole('button',{name:'Propose commitment'}))
  await waitFor(()=>expect(execute).toHaveBeenCalled())
  expect(execute.mock.calls[0][0]).toMatchObject({command:'create',propose:true,data:{ownerId:id,classification:'restricted'}})
})
it('P09_A3: acceptance sends the displayed criteria revision and explicit evidence, never a completion flag',async()=>{
  const execute=vi.fn<DeliverableCommands['execute']>().mockResolvedValue({ok:false,error:mapCommandError({code:'55000'})})
  setup({read:async()=>({...context,state:'submitted',editable:false,manager:true,actions:['accept','revise','cancel']}),execute})
  await screen.findByLabelText(/I verified every criterion/)
  fireEvent.click(screen.getByLabelText(/I verified every criterion/))
  fireEvent.change(screen.getByLabelText('Action reason (required)'),{target:{value:'Criteria independently checked'}})
  fireEvent.change(screen.getByLabelText('Final evidence or criteria verification notes'),{target:{value:'Verified the final checklist reference'}})
  fireEvent.click(screen.getByRole('button',{name:'Accept deliverable'}))
  await screen.findByRole('alert')
  expect(execute.mock.calls[0][0]).toMatchObject({command:'transition',action:'accept',criteriaRevision:2,version:3,evidence:'Verified the final checklist reference'})
  expect(screen.queryByText('Saved. The database confirmed this change.')).toBeNull()
})
it('command adapter preserves server errors and treats malformed success receipts as unconfirmed',async()=>{
  const rpc=vi.fn().mockResolvedValueOnce({data:{workItemId:id,version:4},error:null}).mockResolvedValueOnce({data:{accepted:true},error:null}).mockResolvedValueOnce({data:null,error:{code:'40001',message:'PRIVATE SQL'}})
  const api=createDeliverableCommands(Promise.resolve({rpc}) as unknown as ReturnType<typeof createSupabaseClient>)
  const input={command:'update' as const,id,data:context.data!,version:3}
  expect(await api.execute(input,id)).toEqual({ok:true,value:{workItemId:id,version:4}})
  expect(rpc).toHaveBeenLastCalledWith('update_deliverable',expect.objectContaining({p_expected_version:3,p_request_id:id,p_data:context.data}))
  expect(await api.execute(input,id)).toMatchObject({ok:false,error:{kind:'unavailable',retryable:true}})
  expect(await api.execute(input,id)).toMatchObject({ok:false,error:{kind:'stale_version',retryable:false}})
})
