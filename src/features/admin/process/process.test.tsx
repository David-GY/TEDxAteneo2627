import {render,screen,fireEvent,waitFor} from '@testing-library/react'
import {MemoryRouter} from 'react-router'
import {it,expect,vi} from 'vitest'
import {FinDecisionMemory} from '../../finance/DecisionMemory'
import {ProcessEditor} from './ProcessPage'
it('P38: invalid review retains phase draft and cannot publish; explicit valid review is required',async()=>{
 const api={read:vi.fn(),summary:vi.fn(),preview:vi.fn(async()=>({valid:false,problem:'invalid_phase_dates',version:0,fingerprint:'a'.repeat(64),previous:null,proposed:{},notice:'No authority changed'})),run:vi.fn()}
 render(<MemoryRouter><FinDecisionMemory identity="p38"><ProcessEditor api={api} term="term" identity="member" data={{version:0,phases:[],statuses:[],services:[],units:[],contacts:[],history:[]}} refreshed={()=>{}}/></FinDecisionMemory></MemoryRouter>)
 fireEvent.change(screen.getByLabelText('Phase name'),{target:{value:'Kept phase draft'}});fireEvent.click(screen.getByRole('button',{name:'Review process change'}));await screen.findByRole('region',{name:'Review publication'});expect((screen.getByLabelText('Phase name')as HTMLInputElement).value).toBe('Kept phase draft');expect((screen.getByRole('button',{name:'Publish reviewed process change'})as HTMLButtonElement).disabled).toBe(true);expect(api.run).not.toHaveBeenCalled();await waitFor(()=>expect(api.preview).toHaveBeenCalled())
})
