import {fireEvent,render,screen,waitFor} from '@testing-library/react'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {expect,it,vi} from 'vitest'
import {DeliverablePage} from './DeliverablePage'
import {FinanceGate} from '../finance/FinanceDesk'
import {PublicityGate} from '../publicity/Publicity'
import {ReviewGate} from '../../components/ReviewGate'
import type {FinanceApi} from '../finance/api'
import type {PublicityApi} from '../publicity/api'
import type {DeliverableDetail} from './api'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
it('P35_U1: protected requirement without a submitted case is pending, never not required',()=>{
 render(<ReviewGate title="Finance review (FIN)" status="not_verified" applicability="pending" loading={false}/>)
 expect(screen.getByText('Finance review (FIN): Pending')).toBeTruthy()
})
const item:DeliverableDetail={id,termId:id,title:'Prepare first output',summary:'A permitted summary',owner:{id,name:'River',active:true},leadUnit:null,supportingUnits:[],phase:null,dueAt:null,dueOn:'2027-04-10',originalDueAt:null,originalDueOn:null,overdue:false,blocked:true,blocker:'Waiting for agreed scope',readiness:'blocked',nextAction:'Confirm scope with River',gates:{finance:'not_required',publicity:'not_required',acceptance:'blocked'},updatedAt:'2026-10-28T00:00:00Z',archivedAt:null,version:1,details:{outcome:'Agreed output',acceptanceCriteria:'Reviewed scope',body:'Working notes'}}
function show(element:React.ReactNode){return render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/deliverables/:deliverableId',loader:()=>({termId:id,memberId:id}),element}],{initialEntries:['/deliverables/'+id]})}/>)}
it('P35_U1 R1: owner, date, blocker and next action precede deliberate editing; opening editing cannot grant authority',async()=>{
 const read=vi.fn(async()=>null),execute=vi.fn()
 show(<DeliverablePage api={{read:async()=>item,list:vi.fn()}} commands={{read,execute}}/>)
 await screen.findByRole('heading',{name:item.title})
 expect(screen.getAllByText('River')[0]).toBeTruthy()
 expect(screen.getByText('Apr 10, 2027')).toBeTruthy()
 expect(screen.getAllByText(item.blocker!)[0]).toBeTruthy()
 expect(screen.getAllByText(item.nextAction,{exact:false})[0]).toBeTruthy()
 const edit=screen.getByText('Edit deliverable and workflow').closest('details')!
 expect(edit.open).toBe(false)
 fireEvent.click(screen.getByText('Edit deliverable and workflow'))
 await waitFor(()=>expect(read).toHaveBeenCalled())
 expect(screen.queryByLabelText('Title (required)')).toBeNull()
 expect(execute).not.toHaveBeenCalled()
})
it('P35_U1 R1: only authorized applicability can say not required; pending, unknown and failed checks stay distinct',async()=>{
 const finance={gate:vi.fn(async()=>({state:'not_verified'}))} as unknown as FinanceApi
 const publicity={gate:vi.fn(async()=>({state:'not_verified'}))} as unknown as PublicityApi
 const view=show(<><FinanceGate api={finance} term={id} id={id} applicability="not_required"/><PublicityGate api={publicity} term={id} id={id} applicability="not_required"/></>)
 await screen.findByText('Finance review (FIN): Not required')
 await screen.findByText('Final publicity review (MCD): Not required')
 view.unmount()
 finance.gate=vi.fn(async()=>({state:'pending' as const}));publicity.gate=vi.fn(async()=>({state:'pending' as const}))
 const view2=show(<><FinanceGate api={finance} term={id} id={id} applicability="not_required"/><PublicityGate api={publicity} term={id} id={id} applicability="not_required"/></>)
 await screen.findByText('Finance review (FIN): Pending')
 await screen.findByText('Final publicity review (MCD): Pending')
 view2.unmount()
 show(<><FinanceGate api={{...finance,gate:async()=>null}} term={id} id={id} applicability="not_required"/><PublicityGate api={{...publicity,gate:async()=>{throw Error('PRIVATE case title')}}} term={id} id={id} applicability="not_required"/></>)
 await screen.findByText('Finance review (FIN): Unavailable')
 await screen.findByText('Final publicity review (MCD): Unavailable')
 expect(screen.queryByText('PRIVATE case title')).toBeNull()
})
