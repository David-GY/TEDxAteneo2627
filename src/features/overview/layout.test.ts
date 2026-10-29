import {expect,it} from 'vitest'
import {defaultLayout,resolveLayout,validateLayout,moveWidget,viewStorageKey} from './layout'

it('P40_A1/U1: a layout cannot introduce FIN, arbitrary queries, optional modules or guest destinations',()=>{
 for(const id of ['finance','fin','prism','mentoring','select * from finance']){
  expect(validateLayout({version:1,widgets:[{id,size:'wide'}]},'member')).toBe(false)
  const result=resolveLayout({version:1,widgets:[{id,size:'wide'}]},'member')
  expect(result.repaired).toBe(true);expect(result.layout).toEqual(defaultLayout('member'))
 }
 expect(validateLayout({version:1,widgets:[{id:'deliverables',size:'wide'}]},'guest')).toBe(false)
 expect(validateLayout({version:1,widgets:[{id:'tasks',size:'wide',query:'finance'}]},'member')).toBe(false)
})
it('P40_A3/U1: absent or retired config recovers defaults and never configures away the primary action/help area',()=>{
 expect(resolveLayout(null,'member')).toEqual({layout:defaultLayout('member'),repaired:false})
 expect(resolveLayout({version:1,widgets:[{id:'retired',size:'wide'}]},'member').repaired).toBe(true)
 expect(validateLayout({version:1,widgets:[]},'member')).toBe(true)
 expect(validateLayout({version:1,widgets:[],hideNextActions:true},'member')).toBe(false)
 expect(validateLayout({version:1,widgets:[{id:'tasks',size:'wide'},{id:'tasks',size:'wide'}]},'member')).toBe(false)
 expect(defaultLayout('guest').widgets.every(w=>['tasks','waiting','calendar','resources'].includes(w.id))).toBe(true)
})
it('P40_A2: reordering moves stable IDs without mutating or inventing widgets; device keys isolate terms and subjects',()=>{
 const initial=defaultLayout('member'),copy=structuredClone(initial)
 const moved=moveWidget(initial,initial.widgets[1].id,-1)
 expect(moved.widgets[0]).toEqual(initial.widgets[1]);expect(initial).toEqual(copy)
 expect(moveWidget(initial,initial.widgets[0].id,-1)).toEqual(initial)
 expect(moveWidget(initial,'retired',1)).toEqual(initial)
 expect(viewStorageKey('org','term','membership')).not.toBe(viewStorageKey('org','term','other'))
 expect(viewStorageKey('org','term','membership')).not.toBe(viewStorageKey('org','next','membership'))
})
