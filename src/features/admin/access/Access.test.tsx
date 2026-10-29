import {render,screen,fireEvent,waitFor,within} from '@testing-library/react'
import {MemoryRouter} from 'react-router'
import {it,expect,vi} from 'vitest'
import {AccessHub} from './Access'
import {FinDecisionMemory} from '../../finance/DecisionMemory'
import type {AccessData} from './api'
import {explainImpact} from './presentation'

const sample:AccessData={catalog:[{capability:'committee.manage',scopes:['unit'],resource:'committee',action:'manage',sensitive:false}],roles:[{id:'role-id',name:'Fictional coordinator',state:'published',version:1,permissions:[{capability:'committee.manage',scope:'unit'}]}],ceilings:[],targets:[{id:'recipient-id',name:'Fictional Casey'}],units:[{id:'unit-id',name:'Fictional Events'},{id:'other-unit',name:'Fictional Support'}],records:[],roleVersions:[],assignments:[],nominations:[],history:[],controlVersion:0,mutationAvailable:true,own:{memberId:'member',grants:[],requestedRecordReadable:null,constraints:[]},notice:'Explicit publication'}

it('P35_U4: custody acknowledgment must describe the independently nominated candidate and exact assignment; unknown permissions fail closed',()=>{
 const assignment={id:'assignment',version:1,membershipId:'recipient-id',roleId:'role-id',scope:'unit',unitId:'unit-id',workId:null,from:'2026-10-29T02:00:00Z',to:'2026-11-02T10:30:00Z',state:'active',effective:true,custodian:false}
 const data={...sample,assignments:[assignment],nominations:[{id:'nomination',assignmentId:'assignment',candidateId:'recipient-id',expiresAt:'2026-10-30T02:00:00Z',accepted:false}]}
 const valid=explainImpact(data,'custodian_accept',{nominationId:'nomination',reference:'Independent candidate acknowledgment'})
 expect(valid).toMatchObject({person:'Fictional Casey',scope:'This committee · Fictional Events',nominationExpiry:'2026-10-30T02:00:00Z',reference:'Independent candidate acknowledgment'})
 expect(explainImpact({...data,nominations:[{...data.nominations[0],candidateId:'another-person'}]},'custodian_accept',{nominationId:'nomination',reference:'Cannot acknowledge for someone else'})).toBeNull()
 expect(explainImpact({...data,targets:[]},'assignment_revoke',{assignmentId:'assignment'})).toBeNull()
 expect(explainImpact({...data,roles:[{...sample.roles[0],permissions:[{capability:'unknown.superpower',scope:'unit'}]}]},'assignment_expiry',{assignmentId:'assignment',to:'2026-11-03T10:30:00Z'})).toBeNull()
})

it('P35_U4: named impact review binds the selected person, permission, exact scope and Manila dates; edits invalidate publication',async()=>{
 const api={read:vi.fn(async()=>sample),preflight:vi.fn(),synthetic:vi.fn(),preview:vi.fn(async()=>({version:0,fingerprint:'f'.repeat(64),notice:'Current ceilings rechecked'})),run:vi.fn(async()=>({ok:true as const,value:{id:'assignment',version:1}}))}
 render(<MemoryRouter><FinDecisionMemory identity="named-review"><AccessHub api={api} term="term" identity="member"/></FinDecisionMemory></MemoryRouter>)
 fireEvent.change(await screen.findByLabelText('Access action'),{target:{value:'assignment_grant'}})
 fireEvent.change(screen.getByLabelText('Effective from · Manila'),{target:{value:'2026-10-29T10:00'}});fireEvent.change(screen.getByLabelText('Effective expiry · Manila'),{target:{value:'2026-11-02T18:30'}});fireEvent.change(screen.getByLabelText('Reason for access change'),{target:{value:'Fictional event assignment'}})
 fireEvent.click(screen.getByRole('button',{name:'Review access change'}))
 const review=await screen.findByRole('region',{name:'Review who and what changes'})
 expect(within(review).getByText('Fictional Casey')).toBeTruthy();expect(within(review).getByText('This committee · Fictional Events')).toBeTruthy();expect(within(review).getByText('Manage committee work')).toBeTruthy();expect(within(review).getByText(/Nov 2, 2026/)).toBeTruthy()
 expect(within(review).getByText(/Existing independent review/)).toBeTruthy()
 fireEvent.click(screen.getByLabelText('I reviewed this exact access change'));fireEvent.change(screen.getByLabelText('Assignment unit'),{target:{value:'other-unit'}})
 expect(screen.queryByRole('region',{name:'Review who and what changes'})).toBeNull();expect((screen.getByRole('button',{name:'Publish reviewed access change'}) as HTMLButtonElement).disabled).toBe(true)
 fireEvent.click(screen.getByRole('button',{name:'Review access change'}));await screen.findByRole('region',{name:'Review who and what changes'});fireEvent.click(screen.getByLabelText('I reviewed this exact access change'));fireEvent.click(screen.getByRole('button',{name:'Publish reviewed access change'}));await screen.findByText('Access change published.')
 expect(api.run).toHaveBeenCalledWith(expect.objectContaining({action:'assignment_grant',values:{roleId:'role-id',targetMembershipId:'recipient-id',scope:'unit',unitId:'other-unit',workId:null,from:'2026-10-29T10:00:00+08:00',to:'2026-11-02T18:30:00+08:00'}}),expect.any(String))
})

it('P35_U2/U4: access refresh retains the role permission draft and an uncertain publication keeps its exact reviewed command',async()=>{
 const calls:unknown[]=[];let uncertain=true
 const api={read:vi.fn(async()=>sample),preflight:vi.fn(),synthetic:vi.fn(),preview:vi.fn(async()=>({version:0,fingerprint:'f'.repeat(64),notice:'Current ceilings rechecked'})),run:vi.fn(async(command:unknown,key:string)=>{calls.push([command,key]);return uncertain?{ok:false as const,error:{retryable:true,kind:'unavailable' as const,message:'Uncertain result'}}:{ok:true as const,value:{id:'role',version:1}}})}
 render(<MemoryRouter><FinDecisionMemory identity="access-recovery"><AccessHub api={api} term="term" identity="member"/></FinDecisionMemory></MemoryRouter>)
 fireEvent.change(await screen.findByLabelText('Role name'),{target:{value:'Fictional team helper'}});fireEvent.click(screen.getByLabelText(/Include .*committee/));fireEvent.change(screen.getByLabelText('Reason for access change'),{target:{value:'Fictional scoped role'}})
 fireEvent.click(screen.getByRole('button',{name:'Refresh access inspection'}));await waitFor(()=>expect((screen.getByLabelText('Role name') as HTMLInputElement).value).toBe('Fictional team helper'))
 expect((screen.getByLabelText(/Include .*committee/) as HTMLInputElement).checked).toBe(true)
 fireEvent.click(screen.getByRole('button',{name:'Review access change'}));await screen.findByText('Current ceilings rechecked');fireEvent.click(screen.getByLabelText('I reviewed this exact access change'));fireEvent.click(screen.getByRole('button',{name:'Publish reviewed access change'}));await screen.findByText('Uncertain result')
 fireEvent.click(screen.getByRole('button',{name:'Refresh access inspection'}));await screen.findByRole('button',{name:'Retry identical access change'});uncertain=false;fireEvent.click(screen.getByRole('button',{name:'Retry identical access change'}));await screen.findByText('Access change published.');expect(calls).toHaveLength(2);expect(calls[1]).toEqual(calls[0])
})
it('P34_A3_preflight UI uses fixture preview and exposes no publish or impersonation action',async()=>{const api={read:vi.fn().mockResolvedValue({catalog:[],roles:[],ceilings:[],targets:[],units:[],records:[],mutationAvailable:false,own:{memberId:'member',grants:[],requestedRecordReadable:null,constraints:['No impersonation']},notice:'Inspection only'}),preview:vi.fn(),run:vi.fn(),preflight:vi.fn(),synthetic:vi.fn().mockResolvedValue({synthetic:true,allowsRealAccess:false,scenario:'finance_case',fixture:'Fictional sample only',explanation:'Independent case authority still required'})};render(<MemoryRouter><AccessHub api={api} term="term" identity="member"/></MemoryRouter>);await screen.findByText('Inspection only');expect(screen.queryByRole('button',{name:/publish|assign role|impersonate/i})).toBeNull();fireEvent.click(screen.getByText('Inspect and simulate access (no changes)'));fireEvent.click(screen.getByRole('button',{name:'Run synthetic preview'}));await screen.findByText('Fictional sample only');expect(api.synthetic).toHaveBeenCalledWith('term',{scenario:'finance_case',permissions:[]})})

it('P34 publication requires reviewed exact values and explicit confirmation before mutation',async()=>{
 const api={read:vi.fn().mockResolvedValue({catalog:[{capability:'committee.manage',scopes:['unit'],resource:'committee',action:'manage',sensitive:false}],roles:[],ceilings:[],targets:[],units:[{id:'unit',name:'Fictional unit'}],records:[],roleVersions:[],assignments:[],nominations:[],history:[],controlVersion:0,mutationAvailable:true,own:{memberId:'member',grants:[],requestedRecordReadable:null,constraints:[]},notice:'Explicit publication'}),preflight:vi.fn(),synthetic:vi.fn(),preview:vi.fn().mockResolvedValue({version:0,fingerprint:'f'.repeat(64),notice:'Review exact permission change'}),run:vi.fn().mockResolvedValue({ok:true,value:{id:'role',version:1}})};
 render(<MemoryRouter><AccessHub api={api} term="term" identity="member"/></MemoryRouter>);
 fireEvent.change(await screen.findByLabelText('Role name'),{target:{value:'Fictional manager'}});
 fireEvent.click(screen.getByLabelText('Include Manage committee work'));
 fireEvent.change(screen.getByLabelText('Reason for access change'),{target:{value:'Fictional reviewed need'}});
 fireEvent.click(screen.getByRole('button',{name:'Review access change'}));await screen.findByText('Review exact permission change');
 expect(api.run).not.toHaveBeenCalled();expect((screen.getByRole('button',{name:'Publish reviewed access change'})as HTMLButtonElement).disabled).toBe(true);
 fireEvent.click(screen.getByLabelText('I reviewed this exact access change'));
 fireEvent.click(screen.getByRole('button',{name:'Publish reviewed access change'}));await screen.findByText('Access change published.');
 expect(api.run).toHaveBeenCalledTimes(1);expect((api.run.mock.calls as unknown as [{values:{name:string}}][])[0][0].values.name).toBe('Fictional manager');
})
