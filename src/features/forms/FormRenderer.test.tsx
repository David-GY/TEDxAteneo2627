import {describe,it,expect,vi} from 'vitest'
import {render,screen,fireEvent,waitFor,cleanup} from '@testing-library/react'
import {FormRenderer} from './FormRenderer'
import {definition} from './form.test-data'
import {FormDrafts} from './Drafts'
import {validateForm} from './validation'
const options={members:[],units:[],files:[]}
describe('P20 accessible renderer',()=>{
 it('P20_A3 repeatable-row and empty-group errors target the child input or described fieldset',async()=>{
  const lines:typeof definition={...definition,fields:[{key:'lines',section:'need',label:'Evidence lines',help:'Add named evidence.',classification:'ordinary',type:'line_items',required:true,maxItems:100,itemFields:[{key:'line_description',section:'need',label:'Line description',help:'Name this line.',classification:'ordinary',type:'short_text',required:true}]}]};
  render(<FormRenderer definition={lines} restricted={false} options={options} draftKey="lines" validate={vi.fn()}/>);fireEvent.click(screen.getByRole('button',{name:'Add line to Evidence lines'}));fireEvent.click(screen.getByRole('button',{name:'Check form values'}));await screen.findByRole('alert');fireEvent.click(screen.getByRole('link',{name:/line 1: Line description: Complete/}));expect(document.activeElement).toBe(screen.getByLabelText('Line description (required)'));fireEvent.click(screen.getByRole('button',{name:'Remove line 1'}));fireEvent.click(screen.getByRole('button',{name:'Check form values'}));await screen.findByRole('alert');fireEvent.click(screen.getByRole('link',{name:'Evidence lines: Complete this required field.'}));expect(document.activeElement?.tagName).toBe('FIELDSET');expect(document.activeElement?.getAttribute('aria-invalid')).toBe('true');expect(document.getElementById(document.activeElement!.getAttribute('aria-describedby')!.split(' ')[0])?.textContent).toContain('Add named evidence');cleanup();
 });
 it('P20_A3 focuses an error summary whose link targets the exact labeled control and described error',async()=>{
  const validate=vi.fn(async values=>validateForm(definition,values,options,false));render(<FormRenderer definition={definition} restricted={false} options={options} draftKey="v1" validate={validate}/>);
  fireEvent.change(screen.getByLabelText('Need extra detail? (required)'),{target:{value:'yes'}});fireEvent.click(screen.getByRole('button',{name:'Check form values'}));await waitFor(()=>expect(document.activeElement).toBe(screen.getByRole('alert')));expect(validate).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole('link',{name:/Extra detail: Complete/}));const detail=screen.getByLabelText('Extra detail (required)');expect(document.activeElement).toBe(detail);expect(detail.getAttribute('aria-invalid')).toBe('true');expect(document.getElementById(detail.getAttribute('aria-describedby')!.split(' ').at(-1)! )?.textContent).toContain('required');
  fireEvent.change(detail,{target:{value:'Safe detail'}});fireEvent.click(screen.getByRole('button',{name:'Check form values'}));await screen.findByRole('status');expect(validate).toHaveBeenCalledTimes(1);expect(screen.getByRole('status').textContent).toContain('Nothing was submitted');cleanup();
 });
 it('retains safe inputs across routine unmounts but clears them on identity change; failures never report success',async()=>{
  const validate=vi.fn(async()=>{throw Error('Connection failed. Inputs kept.')});const child=<FormRenderer definition={definition} restricted={false} options={options} draftKey="v1" validate={validate}/>;
  const{rerender}=render(<FormDrafts identity="member-a">{child}</FormDrafts>);fireEvent.change(screen.getByLabelText('Need extra detail? (required)'),{target:{value:'yes'}});fireEvent.change(screen.getByLabelText('Extra detail (required)'),{target:{value:'Safe input'}});rerender(<FormDrafts identity="member-a">Loading access</FormDrafts>);rerender(<FormDrafts identity="member-a">{child}</FormDrafts>);expect((screen.getByLabelText('Extra detail (required)') as HTMLInputElement).value).toBe('Safe input');fireEvent.click(screen.getByRole('button',{name:'Check form values'}));await screen.findByRole('alert');expect(screen.queryByRole('status')).toBeNull();expect((screen.getByLabelText('Extra detail (required)') as HTMLInputElement).value).toBe('Safe input');rerender(<FormDrafts identity="member-b">{child}</FormDrafts>);expect(screen.queryByLabelText('Extra detail (required)')).toBeNull();cleanup();
 });
 it('P20_A3 refuses malicious script/regex definitions before rendering or evaluating any control',()=>{
  const bad={...definition,fields:definition.fields.map(f=>({...f,regex:'(a+)+$',script:'globalThis.executed=true'}))};render(<FormRenderer definition={bad} restricted={false} options={options} draftKey="bad" validate={vi.fn()}/>);expect(screen.getByRole('alert').textContent).toContain('invalid');expect(screen.queryByRole('combobox')).toBeNull();cleanup();
 });
})
