import {cleanup,fireEvent,render,screen} from '@testing-library/react'
import {afterEach,expect,it} from 'vitest'
import {ProposalEditor} from './ProposalEditor'
afterEach(cleanup)
it('P41_U2 foundation: no-send preview explains unavailable channels and keeps actual recipients out of examples',()=>{
 render(<ProposalEditor/>);fireEvent.click(screen.getByText('Try notification timing proposals'))
 fireEvent.change(screen.getByLabelText('Proposed channel'),{target:{value:'email'}})
 fireEvent.click(screen.getByRole('button',{name:'Preview fictional timing (send nothing)'}))
 expect(screen.getByRole('region',{name:'Fictional timing preview'}).textContent).toContain('not connected')
 expect(screen.getByRole('region',{name:'Fictional timing preview'}).textContent).toContain('No recipient lookup')
 expect(screen.queryByRole('button',{name:/publish|activate|send now/i})).toBeNull()
})
it('changed proposals invalidate the old preview and invalid dates explain recovery without a success state',()=>{
 render(<ProposalEditor/>);fireEvent.click(screen.getByText('Try notification timing proposals'));fireEvent.click(screen.getByRole('button',{name:'Preview fictional timing (send nothing)'}))
 expect(screen.getByRole('region',{name:'Fictional timing preview'})).toBeTruthy()
 fireEvent.change(screen.getByLabelText('Days before due'),{target:{value:'3'}});expect(screen.queryByRole('region',{name:'Fictional timing preview'})).toBeNull()
 fireEvent.change(screen.getByLabelText('Example due date · Manila'),{target:{value:''}});fireEvent.click(screen.getByRole('button',{name:'Preview fictional timing (send nothing)'}));expect(screen.getByRole('alert').textContent).toContain('valid')
})
