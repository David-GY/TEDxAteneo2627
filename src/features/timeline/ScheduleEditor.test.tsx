import {render,screen,fireEvent,waitFor} from '@testing-library/react'
import {it,expect,vi} from 'vitest'
import {ScheduleEditor} from './ScheduleEditor'
import type {TimelineApi} from './api'
import {mapCommandError} from '../../lib/commands'
import {ScheduleDrafts} from './ScheduleDrafts'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
const context={id,version:1,plannedStartOn:null,dueOn:'2027-04-10',dueAt:null,canSchedule:true}
function setup(save:TimelineApi['save']){const api:TimelineApi={read:vi.fn(),context:vi.fn(async()=>context),save};render(<ScheduleEditor api={api} id={id}/>);return api}
it('retains a stale date draft and explicitly refreshes the version without replacing input',async()=>{
 const save=vi.fn(async()=>({ok:false as const,error:mapCommandError({code:'40001'})}));const api=setup(save)
 const input=await screen.findByLabelText('Planned start date · Manila');fireEvent.change(input,{target:{value:'2027-04-02'}});fireEvent.click(screen.getByText('Save planned start'))
 await screen.findByRole('alert');expect((input as HTMLInputElement).value).toBe('2027-04-02');expect(screen.queryByRole('status')).toBeNull()
 vi.mocked(api.context).mockResolvedValue({...context,version:2});fireEvent.click(screen.getByText('Refresh schedule version (keep input)'))
 expect((await screen.findByLabelText('Planned start date · Manila') as HTMLInputElement).value).toBe('2027-04-02');await screen.findByText(/Schedule version 2/)
})
it('freezes an uncertain save and retries identical start/version/key until a valid receipt',async()=>{
 const save=vi.fn<TimelineApi['save']>().mockResolvedValueOnce({ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}).mockResolvedValueOnce({ok:true,value:{workItemId:id,version:2}});setup(save)
 const input=await screen.findByLabelText('Planned start date · Manila');fireEvent.change(input,{target:{value:'2027-04-03'}});fireEvent.click(screen.getByText('Save planned start'))
 await screen.findByText('Retry same schedule request');expect(input.closest('fieldset')?.disabled).toBe(true);expect((screen.getByText('Refresh schedule version (keep input)') as HTMLButtonElement).disabled).toBe(true)
 fireEvent.click(screen.getByText('Retry same schedule request'));await screen.findByRole('status');expect(save.mock.calls[1]).toEqual(save.mock.calls[0]);expect(save.mock.calls[0][1]).toBe('2027-04-03');expect(save.mock.calls[0][2]).toBe(1)
})
it('hides the schedule controls after a current permission rejection without claiming success',async()=>{
 setup(vi.fn(async()=>({ok:false as const,error:mapCommandError({code:'42501'})})))
 fireEvent.change(await screen.findByLabelText('Planned start date · Manila'),{target:{value:'2027-04-02'}});fireEvent.click(screen.getByText('Save planned start'))
 await waitFor(()=>expect(screen.queryByLabelText('Planned start date · Manila')).toBeNull());expect(screen.queryByRole('status')).toBeNull()
})
it('retains an exact uncertain date request across an access-check remount, then clears it for another identity',async()=>{
 const save=vi.fn<TimelineApi['save']>().mockResolvedValueOnce({ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}).mockResolvedValueOnce({ok:true,value:{workItemId:id,version:2}})
 const api:TimelineApi={read:vi.fn(),context:vi.fn(async()=>context),save}
 const view=render(<ScheduleDrafts identity="member-A"><ScheduleEditor api={api} id={id}/></ScheduleDrafts>)
 fireEvent.change(await screen.findByLabelText('Planned start date · Manila'),{target:{value:'2027-04-03'}});fireEvent.click(screen.getByText('Save planned start'));await screen.findByText('Retry same schedule request')
 view.rerender(<ScheduleDrafts identity="member-A"><p>Checking access</p></ScheduleDrafts>)
 vi.mocked(api.context).mockResolvedValue({...context,version:2,plannedStartOn:'2027-04-03'})
 view.rerender(<ScheduleDrafts identity="member-A"><ScheduleEditor api={api} id={id}/></ScheduleDrafts>);await screen.findByText('Retry same schedule request');fireEvent.click(screen.getByText('Retry same schedule request'));await screen.findByRole('status');expect(save.mock.calls[1]).toEqual(save.mock.calls[0])
 vi.mocked(api.context).mockResolvedValue(context);view.rerender(<ScheduleDrafts identity="member-B"><ScheduleEditor api={api} id={id}/></ScheduleDrafts>);expect((await screen.findByLabelText('Planned start date · Manila') as HTMLInputElement).value).toBe('');expect(screen.queryByText('Retry same schedule request')).toBeNull()
})
it('purges retained date inputs when fresh record authorization is lost',async()=>{
 const api:TimelineApi={read:vi.fn(),context:vi.fn(async()=>context),save:vi.fn()}
 const view=render(<ScheduleDrafts identity="member-A"><ScheduleEditor api={api} id={id}/></ScheduleDrafts>);fireEvent.change(await screen.findByLabelText('Planned start date · Manila'),{target:{value:'2027-04-04'}})
 view.rerender(<ScheduleDrafts identity="member-A"><p>Checking access</p></ScheduleDrafts>);vi.mocked(api.context).mockResolvedValue(null);view.rerender(<ScheduleDrafts identity="member-A"><ScheduleEditor api={api} id={id}/></ScheduleDrafts>);await screen.findByText('Schedule unavailable or access changed.')
 vi.mocked(api.context).mockResolvedValue(context);fireEvent.click(screen.getByText('Refresh schedule version (keep input)'));expect((await screen.findByLabelText('Planned start date · Manila') as HTMLInputElement).value).toBe('')
})
