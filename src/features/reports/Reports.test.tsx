import {cleanup,render,screen,fireEvent}from'@testing-library/react'
import {afterEach,it,expect,vi}from'vitest'
import {createMemoryRouter,RouterProvider}from'react-router'
import {Reports}from'./Reports'
import type{ReportsApi,Report}from'./api'
import{emptyMeasurements}from'./reportFixture'
afterEach(cleanup)
const snapshot={...emptyMeasurements,asOf:'2026-10-30T00:00:00Z',week:'2026-10-26',weekEnd:'2026-11-01',timezone:'Asia/Manila',units:[],summary:{total:1,open:1,overdue:0,originalOverdue:1,blocked:0,assignedOpen:0,unassignedOpen:0,readyDeliverables:0},usage:{state:'unconfigured'},items:[{id:'work',kind:'deliverable',title:'Prepare signage',reference:'DEL-027',state:'in_progress',dueOn:'2026-11-03',dueAt:null,originalDueOn:'2026-10-20',originalDueAt:null,overdue:false,originalOverdue:true,blockedSince:null,blockedDays:null,checksMet:false,declaredEffort:null,href:'/deliverables/work?term=term'}],total:1,nextAfter:null}as Report
function show(api:ReportsApi){render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/',loader:()=>({termId:'term',memberId:'member',capabilities:['reports.view']}),element:<Reports api={api}/>}])}/>)}
it('P44_U1/U2 renders scoped queue age and calendar turnaround with explicit denominators; zero samples never imply zero-day performance',async()=>{
 const data={...snapshot,...emptyMeasurements,operations:{...emptyMeasurements.operations,queue:{total:1,unassigned:1,assigned:0,prerequisites:0,unknownAge:0,oldestDays:3,items:[{id:'case',title:'General support',reference:'OPS-027',revision:2,state:'paused',lane:'unassigned',since:'2026-10-27T00:00:00Z',ageDays:3,href:'/reviews/term/case'}]}}}as Report
 show({read:async()=>data,recordView:async()=>{}})
 const source=await screen.findByRole('link',{name:'General support'});expect(source.getAttribute('href')).toBe('/reviews/term/case')
 expect(screen.getByText(/Oldest recorded wait: 3 calendar days/)).toBeTruthy()
 expect(screen.getByText(/No permitted review decisions in this period/)).toBeTruthy()
 expect(screen.getByText(/No permitted receiver responses in this period/)).toBeTruthy()
 expect(screen.getByText(/not a business-day SLA/)).toBeTruthy()
 expect(screen.getByText(/1 open tasks have no recorded effort/)).toBeTruthy()
})
it('explains original overdue and opens only the authorized source; unconfigured activity has no fake percentage',async()=>{
 show({read:async()=>snapshot,recordView:async()=>{}});const link=await screen.findByRole('link',{name:'Prepare signage'});expect(link.getAttribute('href')).toBe('/deliverables/work?term=term');expect(screen.getByText(/Activity measurement is not configured/)).toBeTruthy();expect(screen.queryByText('0%')).toBeNull();expect(screen.getByText(/Original deadline: Oct 20, 2026/)).toBeTruthy();expect(screen.getByText(/Refreshed.*8:00/)).toBeTruthy()
})
it('a failed refresh hides prior metrics and retains the selected week for retry',async()=>{
 const read=vi.fn().mockResolvedValueOnce(snapshot).mockRejectedValueOnce(Error()).mockResolvedValue(snapshot)
 show({read,recordView:async()=>{}});await screen.findByRole('link',{name:'Prepare signage'});fireEvent.click(screen.getByRole('button',{name:'Refresh report'}));await screen.findByRole('alert');expect(screen.queryByRole('link',{name:'Prepare signage'})).toBeNull();const week=(screen.getByLabelText('Week starting Monday (Manila)')as HTMLInputElement).value;fireEvent.click(screen.getByRole('button',{name:'Refresh report'}));await screen.findByRole('link',{name:'Prepare signage'});expect((screen.getByLabelText('Week starting Monday (Manila)')as HTMLInputElement).value).toBe(week)
})
it('an old response cannot replace the report after changing investigation scope',async()=>{
 let finish:(value:Report)=>void=()=>{};const read=vi.fn().mockImplementationOnce(()=>new Promise(resolve=>{finish=resolve})).mockResolvedValue({...snapshot,items:[],total:0})
 show({read,recordView:async()=>{}});await screen.findByLabelText('Work to investigate');fireEvent.change(screen.getByLabelText('Work to investigate'),{target:{value:'blocked'}});await screen.findByText('No permitted work matches these filters. Check committee scope or choose another work filter.');finish(snapshot);await new Promise(resolve=>setTimeout(resolve,0));expect(screen.queryByRole('link',{name:'Prepare signage'})).toBeNull()
})
