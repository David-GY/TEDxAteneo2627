import {expect,it} from 'vitest'
import {defaultProposal,validProposal,planReminder,mergePlannedReminders,externalTemplate} from './proposal'
const work='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
it('P41_A1 foundation: Manila boundaries and overlapping/retried windows produce the same canonical reminder identity',()=>{
 const r=defaultProposal()
 const a=planReminder(r,work,'2027-04-17','2027-04-15T00:00:00Z','2027-04-18T00:00:00Z')
 expect(a.map(x=>[x.event,x.at])).toEqual([['before_due','2027-04-15T00:00:00.000Z'],['due','2027-04-17T00:00:00.000Z']])
 const b=planReminder(r,work,'2027-04-17','2027-04-17T00:00:00Z','2027-04-19T00:00:00Z')
 expect(mergePlannedReminders([...a,...b,...a]).map(x=>x.event)).toEqual(['before_due','due','overdue'])
 expect(b[0].key).toBe(a[1].key)
})
it('quiet hours cross midnight, preserve logical dates and never silence required in-app work',()=>{
 const r={...defaultProposal(),hour:21,channel:'email' as const}
 expect(planReminder(r,work,'2027-04-17','2027-04-17T00:00:00Z','2027-04-19T00:00:00Z')[0]).toMatchObject({event:'due',logicalDay:'2027-04-17',at:'2027-04-18T00:00:00.000Z',available:false})
 expect(planReminder(r,work,'2027-04-17','2027-04-17T00:00:00Z','2027-04-19T00:00:00Z').every(x=>!x.optionalDelivery)).toBe(true)
 const muted={...r,mode:'mute' as const}
 expect(planReminder(muted,work,'2027-04-17','2027-04-17T00:00:00Z','2027-04-19T00:00:00Z').every(x=>!x.optionalDelivery&&x.requiredWorkVisible)).toBe(true)
 expect(planReminder({...r,channel:'in_app'},work,'2027-04-17','2027-04-17T00:00:00Z','2027-04-19T00:00:00Z')[0].at).toBe('2027-04-17T13:00:00.000Z')
})
it('strict proposals reject scripts, recipient lists, template payloads, invalid dates, unsupported channels and unbounded windows',()=>{
 for(const bad of [{...defaultProposal(),recipients:[work]},{...defaultProposal(),template:'{{private_amount}}'},{...defaultProposal(),hour:24},{...defaultProposal(),beforeDays:100},{...defaultProposal(),channel:'messenger'},{...defaultProposal(),quietEnd:20},{...defaultProposal(),dueDay:'true'},Object.assign(Object.create({mode:'mute'}),defaultProposal())])expect(validProposal(bad)).toBe(false)
 expect(()=>planReminder(defaultProposal(),work,'2027-02-30','2027-01-01T00:00:00Z','2027-01-03T00:00:00Z')).toThrow()
 expect(()=>planReminder(defaultProposal(),work,'2027-04-17','2027-01-01T00:00:00Z','2028-01-01T00:00:00Z')).toThrow()
 expect(()=>externalTemplate('private title')).toThrow()
 expect(externalTemplate('action_link')).toBe('You have an update. Open your workspace to check the current permitted action.')
 expect(validProposal({...defaultProposal(),channel:{toString:()=> 'email'}})).toBe(false)
 expect(()=>planReminder(defaultProposal(),work,'2027-04-17','2027-04-17T00:00:00','2027-04-18T00:00:00')).toThrow()
})
it('edited cadence and leap-day arithmetic are bounded without changing canonical work identity',()=>{
 const r={...defaultProposal(),overdueEveryDays:2}
 expect(planReminder(r,work,'2028-02-28','2028-02-29T00:00:00Z','2028-03-04T00:00:00Z').map(x=>x.logicalDay)).toEqual(['2028-02-29','2028-03-02'])
 const atEnd=planReminder(defaultProposal(),work,'2027-04-17','2027-04-17T00:00:00Z','2027-04-17T00:00:00Z');expect(atEnd).toEqual([])
})
