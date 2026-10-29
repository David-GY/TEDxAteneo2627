import {useState} from 'react'
import {render,screen,fireEvent} from '@testing-library/react'
import {it,expect} from 'vitest'
import {ConditionEditor} from './ConditionEditor'
import type {Condition} from '../../requests/catalog/api'
it('bounded groups author typed predicates without code or option IDs',()=>{
 let latest:Condition={op:'eq',field:'purpose',value:''}
 function Editor(){const[v,set]=useState(latest);return <ConditionEditor value={v} fields={[{key:'purpose',section:'need',label:'Purpose',help:'',required:true,type:'short_text',classification:'ordinary'}]} change={x=>{latest=x;set(x)}}/>}
 render(<Editor/>);fireEvent.click(screen.getByRole('button',{name:'Group this rule'}));expect(latest.op).toBe('and');fireEvent.change(screen.getByLabelText('Combine rules · root'),{target:{value:'or'}});expect(latest.op).toBe('or');fireEvent.click(screen.getByRole('button',{name:'Add rule · root'}));const group=latest as Condition;expect('conditions'in group&&group.conditions.length).toBe(2)
})
