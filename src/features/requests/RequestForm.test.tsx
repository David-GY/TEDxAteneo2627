import {describe,it,expect,vi} from 'vitest'
import {render,screen,fireEvent,waitFor,cleanup} from '@testing-library/react'
import {FormRenderer} from '../forms/FormRenderer'
import {definition} from '../forms/form.test-data'
import {FormDrafts} from '../forms/Drafts'
const options={members:[],units:[],files:[]}
describe('P21 request form intent',()=>{
 it('saves incomplete current values but submits only after required validation',async()=>{
  const validate=vi.fn(async(values,centavos)=>({valid:true,errors:{},values,snapshots:{},requestedCentavos:centavos}));render(<FormRenderer definition={definition} restricted={false} options={options} draftKey="request-v1" mode="request" validate={validate}/>);
  fireEvent.click(screen.getByRole('button',{name:'Save draft'}));await waitFor(()=>expect(validate).toHaveBeenCalledTimes(1));expect(validate.mock.calls[0]).toEqual([{},null,'save']);await screen.findByRole('status');
  fireEvent.click(screen.getByRole('button',{name:'Submit request'}));await screen.findByRole('alert');expect(validate).toHaveBeenCalledTimes(1);
  fireEvent.change(screen.getByLabelText('Need extra detail? (required)'),{target:{value:'no'}});fireEvent.click(screen.getByRole('button',{name:'Submit request'}));await waitFor(()=>expect(validate).toHaveBeenCalledTimes(2));expect(validate.mock.calls[1]).toEqual([{detail_needed:'no'},null,'submit']);cleanup();
 });
 it('retains unsaved values over newer initial props and prevents edits while recovering an uncertain command',()=>{
  const props={definition,restricted:false,options,draftKey:'request-v1',mode:'request' as const,validate:vi.fn()},initial={values:{detail_needed:'yes',detail:'Server draft'},money:''};const{rerender}=render(<FormDrafts identity="member-a"><FormRenderer {...props} initial={initial}/></FormDrafts>);
  fireEvent.change(screen.getByLabelText('Extra detail (required)'),{target:{value:'Private unsaved input'}});rerender(<FormDrafts identity="member-a">Checking access</FormDrafts>);rerender(<FormDrafts identity="member-a"><FormRenderer {...props} initial={{...initial,values:{...initial.values,detail:'Newer server draft'}}} locked/></FormDrafts>);const field=screen.getByLabelText('Extra detail (required)')as HTMLInputElement;expect(field.value).toBe('Private unsaved input');expect(field.matches(':disabled')).toBe(true);fireEvent.click(screen.getByRole('button',{name:'Submit request'}));expect(props.validate).not.toHaveBeenCalled();cleanup();
 });
})
