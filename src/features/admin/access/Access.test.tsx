import {render,screen,fireEvent} from '@testing-library/react'
import {MemoryRouter} from 'react-router'
import {it,expect,vi} from 'vitest'
import {AccessHub} from './Access'
it('P34_A3_preflight UI uses fixture preview and exposes no publish or impersonation action',async()=>{const api={read:vi.fn().mockResolvedValue({catalog:[],roles:[],ceilings:[],targets:[],units:[],records:[],mutationAvailable:false,own:{memberId:'member',grants:[],requestedRecordReadable:null,constraints:['No impersonation']},notice:'Inspection only'}),preview:vi.fn(),run:vi.fn(),preflight:vi.fn(),synthetic:vi.fn().mockResolvedValue({synthetic:true,allowsRealAccess:false,scenario:'finance_case',fixture:'Fictional sample only',explanation:'Independent case authority still required'})};render(<MemoryRouter><AccessHub api={api} term="term" identity="member"/></MemoryRouter>);await screen.findByText('Inspection only');expect(screen.queryByRole('button',{name:/publish|assign role|impersonate/i})).toBeNull();fireEvent.click(screen.getByRole('button',{name:'Run synthetic preview'}));await screen.findByText('Fictional sample only');expect(api.synthetic).toHaveBeenCalledWith('term',{scenario:'finance_case',permissions:[]})})

it('P34 publication requires reviewed exact values and explicit confirmation before mutation',async()=>{
 const api={read:vi.fn().mockResolvedValue({catalog:[{capability:'committee.manage',scopes:['unit'],resource:'committee',action:'manage',sensitive:false}],roles:[],ceilings:[],targets:[],units:[{id:'unit',name:'Fictional unit'}],records:[],roleVersions:[],assignments:[],nominations:[],history:[],controlVersion:0,mutationAvailable:true,own:{memberId:'member',grants:[],requestedRecordReadable:null,constraints:[]},notice:'Explicit publication'}),preflight:vi.fn(),synthetic:vi.fn(),preview:vi.fn().mockResolvedValue({version:0,fingerprint:'f'.repeat(64),notice:'Review exact permission change'}),run:vi.fn().mockResolvedValue({ok:true,value:{id:'role',version:1}})};
 render(<MemoryRouter><AccessHub api={api} term="term" identity="member"/></MemoryRouter>);
 fireEvent.change(await screen.findByLabelText('Role name'),{target:{value:'Fictional manager'}});
 fireEvent.click(screen.getByLabelText('Include committee.manage'));
 fireEvent.change(screen.getByLabelText('Reason for access change'),{target:{value:'Fictional reviewed need'}});
 fireEvent.click(screen.getByRole('button',{name:'Review access change'}));await screen.findByText('Review exact permission change');
 expect(api.run).not.toHaveBeenCalled();expect((screen.getByRole('button',{name:'Publish reviewed access change'})as HTMLButtonElement).disabled).toBe(true);
 fireEvent.click(screen.getByLabelText('I reviewed this exact access change'));
 fireEvent.click(screen.getByRole('button',{name:'Publish reviewed access change'}));await screen.findByText('Access change published.');
 expect(api.run).toHaveBeenCalledTimes(1);expect((api.run.mock.calls as unknown as [{values:{name:string}}][])[0][0].values.name).toBe('Fictional manager');
})
