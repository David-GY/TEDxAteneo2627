import {render,screen,fireEvent,waitFor} from '@testing-library/react'
import {MemoryRouter} from 'react-router'
import {describe,it,expect,vi} from 'vitest'
import {ResourcesHub} from './Resources'
import type {ResourcesApi,ResourcePage} from './api'
const empty:ResourcePage={items:[],drafts:[],progress:[],checklistVersion:1,canPublishCore:false,managedUnits:[]}
function setup(value=empty){const api:ResourcesApi={read:vi.fn().mockResolvedValue(value),run:vi.fn().mockResolvedValue({ok:true,value:{version:1}})};render(<MemoryRouter><ResourcesHub term="term" identity="member" guest={false} api={api}/></MemoryRouter>);return api}
describe('P32',()=>{
 it('P32_A1 essential guidance and checklist need no affiliation/course disclosure',async()=>{const api=setup();await screen.findByText('No published guidance yet');expect(screen.queryByLabelText(/affiliation|course/i)).toBeNull();for(const name of ['Confirm profile','Find contacts','Locate work','Understand review gates'])fireEvent.click(screen.getByRole('button',{name}));await waitFor(()=>expect(api.run).toHaveBeenCalledTimes(4));expect(screen.getByText(/No assigned work yet/)).toBeTruthy();expect(screen.getByRole('link',{name:'Open account'})).toBeTruthy()})
 it('P32_A2 glossary uses stable IDs and safe text, preserving alias routes',async()=>{setup({...empty,items:[{id:'a',version:2,publishedVersion:2,label:'New label',body:'<img src=x onerror=alert(1)>',alias:'new-label',ownerId:'m',ownerName:'Owner',reviewOn:'2027-04-17',reviewDue:false,serviceId:null,visibility:'core',unitId:null,kind:'glossary',essential:false,links:[],canEdit:false,targets:[]}]});await screen.findByText('New label');expect(screen.getByText('<img src=x onerror=alert(1)>')).toBeTruthy();expect(document.querySelector('img')).toBeNull();expect(document.getElementById('resource-a')).toBeTruthy()})
 it('P32_A3 practice task/request never calls production or progress APIs; tour can be skipped/revisited',async()=>{const api=setup();await screen.findByText('No published guidance yet');fireEvent.change(screen.getByLabelText('Practice title'),{target:{value:'Zero-cost fundraiser'}});fireEvent.change(screen.getByLabelText('Practice date'),{target:{value:'2027-04-17'}});fireEvent.change(screen.getByLabelText('Practice done criteria or request scope'),{target:{value:'Fictional scoped outcome'}});fireEvent.click(screen.getByRole('button',{name:'Try practice request'}));expect(screen.getByText(/Practice only: no real task, request or FIN case/)).toBeTruthy();fireEvent.click(screen.getByRole('button',{name:'Try practice task'}));expect(api.run).not.toHaveBeenCalled();fireEvent.click(screen.getByRole('button',{name:'Skip optional tour'}));await waitFor(()=>expect(api.run).toHaveBeenCalledTimes(1));fireEvent.click(screen.getByRole('button',{name:'Revisit optional tour'}));expect(screen.getByText(/Start with your account/)).toBeTruthy()})
})

it('P35_U3 R1 entry: guest first-work/help routes avoid roster and do not call core resources APIs',()=>{
 const api:ResourcesApi={read:vi.fn(),run:vi.fn()}
 render(<MemoryRouter><ResourcesHub term="term" identity="guest" guest={true} api={api}/></MemoryRouter>)
 expect(screen.getByRole('link',{name:'Open my work'}).getAttribute('href')).toBe('/shared')
 expect(screen.getByRole('link',{name:'Find help'}).getAttribute('href')).toBe('/account')
 expect(screen.queryByRole('link',{name:'Open People directory'})).toBeNull()
 expect(api.read).not.toHaveBeenCalled()
 expect(api.run).not.toHaveBeenCalled()
})
