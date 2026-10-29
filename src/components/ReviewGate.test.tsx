import {render,screen,cleanup} from '@testing-library/react'
import {it,expect} from 'vitest'
import {ReviewGate} from './ReviewGate'

it('P38_U1: shared finance/publicity labels distinguish current evidence, waiting, not required and unavailable',()=>{
 for(const title of ['Finance review (FIN)','Final publicity review (MCD)']){
  for(const [status,applicability,label] of [
   ['authorized','pending','Approved for this revision'],['reviewed','verified','Approved for this revision'],
   ['pending','verified','Waiting for review'],['not_verified','pending','Waiting for review'],
   ['not_verified','not_required','Not required'],['not_verified','pending_assessment','Unavailable'],
   ['Approved','not_required','Unavailable'],[null,'not_required','Unavailable']
  ] as const){
   render(<ReviewGate title={title} status={status} applicability={applicability} loading={false}/>);
   expect(screen.getByRole('status').textContent).toBe(title+': '+label);cleanup()
  }
 }
})
it('a refreshing gate never displays a previous approval as current',()=>{
 render(<ReviewGate title="Finance review (FIN)" status="authorized" applicability="verified" loading/>);
 expect(screen.getByRole('status').textContent).toBe('Finance review (FIN): Checking…')
})
