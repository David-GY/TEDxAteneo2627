import {render,screen,fireEvent,waitFor} from '@testing-library/react'
import {MemoryRouter} from 'react-router'
import {expect,it,vi} from 'vitest'
import {FinDecisionMemory} from '../../finance/DecisionMemory'
import {ConfigurationEditor} from './ConfigurationEditor'
import {createConfigurationApi,type ConfigurationData,type ConfigurationApi} from './api'

const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', form='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', workflow='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', draft='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4'
export const sample:ConfigurationData={typeId:id,typeLabel:'Fictional support service',termId:id,governedKind:'general',classification:'ordinary',serviceLabel:'Fictional Support',currentMembershipId:id,currentMemberName:'Fictional River',formVersionId:form,workflowVersionId:workflow,
 reviewers:[{id,name:'Fictional River',role:'Fictional service reviewer'}],formDefinition:{schemaVersion:1,sections:[{key:'need',label:'Your request'}],fields:[{key:'purpose',section:'need',label:'Purpose',help:'Explain the need',type:'short_text',required:true,classification:'ordinary',maxLength:500}]},
 workflowDefinition:{schemaVersion:1,stages:[{key:'review',label:'Review the request',review:'one',reviewers:[id],outcome:'approved',revisionStage:'review',entryFields:['purpose'],reminderDays:7}]},drafts:[],history:[]}
const api=():ConfigurationApi=>({list:vi.fn(),read:vi.fn(),preview:vi.fn(async()=>({draftId:draft,version:1,valid:true,problem:null,kind:'workflow' as const,reviewHash:'a'.repeat(64),requesterId:id,previousDefinition:sample.workflowDefinition,definition:sample.workflowDefinition,changed:true,existingCasesRemainPinned:true as const,liveActivationChanged:false as const})),run:vi.fn(async()=>({ok:true as const,value:{draftId:draft,version:1}}))})
function show(data=sample,client=api(),identity='fixture'){return{client,...render(<MemoryRouter><FinDecisionMemory identity={identity}><ConfigurationEditor api={client} data={data} identity={identity} refreshed={()=>{}}/></FinDecisionMemory></MemoryRouter>)}}

it('P37_U1 draft: named stage/reviewer controls preserve stable keys; edits invalidate the reviewed publication',async()=>{
 const saved={...sample,drafts:[{draftId:draft,kind:'workflow' as const,version:1,definition:sample.workflowDefinition,baseFormVersionId:form,baseWorkflowVersionId:workflow,rollbackVersionId:null,publishedVersionId:null,updatedAt:'2026-10-29T01:00:00Z'}]}
 const {client}=show(saved)
 expect((screen.getByLabelText('Reviewer · Fictional River') as HTMLInputElement).checked).toBe(true)
 expect(screen.queryByRole('textbox',{name:/json/i})).toBeNull()
 fireEvent.click(screen.getByRole('button',{name:'Validate and preview saved draft'}))
 await screen.findByRole('region',{name:'Review publication'})
 expect((screen.getByRole('button',{name:'Publish reviewed configuration'}) as HTMLButtonElement).disabled).toBe(true)
 fireEvent.change(screen.getByLabelText('Reason for configuration change'),{target:{value:'Clearer fictional service routing'}})
 fireEvent.click(screen.getByLabelText('I reviewed this exact change'))
 expect((screen.getByRole('button',{name:'Publish reviewed configuration'}) as HTMLButtonElement).disabled).toBe(false)
 fireEvent.change(screen.getByLabelText('Stage 1 name'),{target:{value:'Check final evidence'}})
 expect(screen.queryByRole('region',{name:'Review publication'})).toBeNull()
 fireEvent.click(screen.getByRole('button',{name:'Save private draft'}))
 await waitFor(()=>expect(client.run).toHaveBeenCalled())
 const command=vi.mocked(client.run).mock.calls[0][0]
 expect(command.action).toBe('save')
 if(command.action==='save')expect(command.definition).toMatchObject({stages:[{key:'review',label:'Check final evidence'}]})
})

it('P37_U2 draft: stale save retains values; uncertain save retries the exact command/key through remount',async()=>{
 const client=api();vi.mocked(client.run).mockResolvedValueOnce({ok:false,error:{kind:'unavailable',message:'Check whether saved, then retry.',retryable:true}}).mockResolvedValueOnce({ok:true,value:{draftId:draft,version:1}})
 const first=show(sample,client,'retry-fixture')
 fireEvent.change(screen.getByLabelText('Stage 1 name'),{target:{value:'Kept after uncertain save'}})
 fireEvent.click(screen.getByRole('button',{name:'Save private draft'}));await screen.findByText(/Check whether saved, then retry\./)
 expect((screen.getByRole('button',{name:'Form wording'}) as HTMLButtonElement).disabled).toBe(true)
 first.rerender(<MemoryRouter><FinDecisionMemory identity="retry-fixture"><div/></FinDecisionMemory></MemoryRouter>)
 first.rerender(<MemoryRouter><FinDecisionMemory identity="retry-fixture"><ConfigurationEditor api={client} data={sample} identity="retry-fixture" refreshed={()=>{}}/></FinDecisionMemory></MemoryRouter>)
 expect((screen.getByLabelText('Stage 1 name') as HTMLInputElement).value).toBe('Kept after uncertain save')
 fireEvent.click(screen.getByRole('button',{name:'Retry identical configuration command'}))
 await waitFor(()=>expect(client.run).toHaveBeenCalledTimes(2))
 expect(vi.mocked(client.run).mock.calls[0]).toEqual(vi.mocked(client.run).mock.calls[1])
})

it('an uncertain form save keeps the form editor selected after refresh/remount',async()=>{
 const client=api();vi.mocked(client.run).mockResolvedValue({ok:false,error:{kind:'unavailable',message:'Uncertain form save.',retryable:true}})
 const view=show(sample,client,'form-retry-fixture')
 fireEvent.click(screen.getByRole('button',{name:'Form wording'}));fireEvent.change(screen.getByLabelText('Question 1 label'),{target:{value:'Keep my form label'}});fireEvent.click(screen.getByRole('button',{name:'Save private draft'}));await screen.findByText(/Uncertain form save/)
 view.rerender(<MemoryRouter><FinDecisionMemory identity="form-retry-fixture"><div/></FinDecisionMemory></MemoryRouter>)
 view.rerender(<MemoryRouter><FinDecisionMemory identity="form-retry-fixture"><ConfigurationEditor api={client} data={sample} identity="form-retry-fixture" refreshed={()=>{}}/></FinDecisionMemory></MemoryRouter>)
 expect((screen.getByLabelText('Question 1 label') as HTMLInputElement).value).toBe('Keep my form label')
 expect(screen.getByRole('button',{name:'Retry identical configuration command'})).toBeTruthy()
})

it('configuration API fails closed on mismatched service and malformed review metadata',async()=>{
 const rpc=vi.fn(async()=>({data:{...sample,typeId:form},error:null}))
 const client=createConfigurationApi(Promise.resolve({rpc}) as never)
 await expect(client.read(id)).rejects.toThrow()
 rpc.mockResolvedValue({data:{...sample,typeId:id},error:null})
 expect((await client.read(id)).typeId).toBe(id)
 rpc.mockResolvedValue({data:{draftId:draft,valid:true,version:1,reviewHash:'fake'},error:null} as never)
 await expect(client.preview(draft,id)).rejects.toThrow()
})

it('an invalid private form label stays editable and can receive a validation explanation',async()=>{
 const invalid={...sample.formDefinition,fields:sample.formDefinition.fields.map(f=>({...f,label:''}))}
 const data={...sample,drafts:[{draftId:draft,kind:'form' as const,version:1,definition:invalid,baseFormVersionId:form,baseWorkflowVersionId:workflow,rollbackVersionId:null,publishedVersionId:null,updatedAt:'2026-10-29T01:00:00Z'}]}
 const rpc=vi.fn(async()=>({data,error:null})),client=createConfigurationApi(Promise.resolve({rpc})as never)
 expect((await client.read(id)).drafts[0].definition).toEqual(invalid)
})

it('stage reordering preserves keys and removing an entry condition changes the saved definition',async()=>{
 const {client}=show()
 fireEvent.click(screen.getByText('Entry condition and stable step details'))
 fireEvent.click(screen.getByRole('button',{name:'Add entry condition for step 1'}))
 fireEvent.click(screen.getByRole('button',{name:'Remove entry condition for step 1'}))
 fireEvent.click(screen.getByRole('button',{name:'Add review step'}))
 fireEvent.click(screen.getByRole('button',{name:'Move step 2 up'}))
 fireEvent.click(screen.getByRole('button',{name:'Save private draft'}))
 await waitFor(()=>expect(client.run).toHaveBeenCalled())
 const command=vi.mocked(client.run).mock.calls[0][0]
 if(command.action!=='save'||!('stages'in command.definition))throw Error('Expected saved workflow')
 expect(command.definition.stages[1].key).toBe('review')
 expect(command.definition.stages[1].condition).toBeUndefined()
 expect(command.definition.stages[0].outcome).toBe('pending')
 expect(command.definition.stages[1].outcome).toBe('approved')
})
