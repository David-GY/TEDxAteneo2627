import {fireEvent,render,screen} from '@testing-library/react'
import {expect,it,vi} from 'vitest'
import {createWorkReferencesApi,validReferenceText} from './api'
import {WorkReference} from './WorkReference'
import type {createSupabaseClient} from '../../lib/supabase'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',other='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'
it('P36_U1/U2: reference validation preserves numbers beyond 999 and rejects alternate padding, unsafe integers and another kind',()=>{
 for(const text of ['TASK-001','TASK-999','TASK-1000','TASK-9007199254740991'])expect(validReferenceText(text,'task')).toBe(true)
 for(const text of ['TASK-000','TASK-01','TASK-0001','TASK-9007199254740992','DEL-012','TASK-1e3','TASK-001 '])expect(validReferenceText(text,'task')).toBe(false)
})
it('P36_U2: exact lookup respects the server null outcome and refuses a different term, reference or kind',async()=>{
 const rpc=vi.fn().mockResolvedValue({data:null,error:null}),api=createWorkReferencesApi(Promise.resolve({rpc}) as unknown as ReturnType<typeof createSupabaseClient>)
 expect(await api.resolve(id,'task','TASK-027')).toBeNull();expect(rpc).toHaveBeenLastCalledWith('resolve_work_reference',{p_term_id:id,p_kind:'task',p_reference:'TASK-027'})
 const result={id,kind:'task',title:'Permitted task',reference:{value:'TASK-027',termId:id,termLabel:'2026–27'}}
 for(const bad of [{...result,kind:'deliverable'},{...result,reference:{...result.reference,termId:other}},{...result,reference:{...result.reference,value:'TASK-028'}}]){
  rpc.mockResolvedValueOnce({data:bad,error:null});await expect(api.resolve(id,'task','TASK-027')).rejects.toThrow('Work reference unavailable')
 }
 rpc.mockResolvedValueOnce({data:result,error:null});expect(await api.resolve(id,'task','TASK-027')).toEqual(result)
 const before=rpc.mock.calls.length;expect(await api.resolve(id,'task','TASK-0001')).toBeNull();expect(rpc.mock.calls.length).toBe(before)
})
it('P36_U2: a pending/unissued record never exposes a copy-reference success; rejected clipboard writes keep selectable context',async()=>{
 const writeText=vi.fn().mockRejectedValue(Error('Clipboard denied'));Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText}})
 const {rerender}=render(<WorkReference id={id} kind="task"/>);expect(screen.queryByRole('button',{name:'Copy reference'})).toBeNull();expect(screen.queryByRole('status')).toBeNull()
 rerender(<WorkReference id={id} kind="task" reference={{value:'TASK-027',termId:other,termLabel:'2027–28'}}/>);fireEvent.click(screen.getByRole('button',{name:'Copy reference'}));await screen.findByText('Copy unavailable. Select the reference or link below to copy.')
 expect(writeText).toHaveBeenCalledWith('TASK-027 · 2027–28');expect((screen.getByLabelText('Work link to copy') as HTMLInputElement).value).toBe(new URL('/tasks/'+id,window.location.origin).href)
 expect(screen.queryByText('Reference copied.')).toBeNull()
})
