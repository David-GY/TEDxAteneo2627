import {it,expect} from 'vitest'
import {getVisibleNavigation} from '../../../app/navigation'
import {validSitePresentation,applyNavigationPresentation,type SitePresentation} from './presentation'
const draft:SitePresentation={schemaVersion:1,labels:{tasks:'My event work'},order:['tasks','overview'],accent:'#b82320',blocks:[{id:'welcome',kind:'text',title:'Start with your work',body:'Open your assignments, then find help in Resources.'}]}
it('P39_A2 foundation: wording/order preserve route identity and already-filtered permissions for member/head/guest',()=>{
 expect(validSitePresentation(draft)).toBe(true)
 for(const context of [{audience:'core' as const,capabilities:[]},{audience:'core' as const,capabilities:['admin.configure' as const]},{audience:'guest' as const,capabilities:['admin.configure' as const]}]){
  const original=getVisibleNavigation(context),next=applyNavigationPresentation(original,draft)
  expect(next.find(x=>x.id==='tasks')?.label).toBe('My event work')
  expect(next.map(x=>[x.id,x.href,x.capability]).sort()).toEqual(original.map(x=>[x.id,x.href,x.capability]).sort())
 }
})
it('P39_A3 foundation rejects scripts/HTML, unknown routes/keys, logo overrides and low-contrast token choices',()=>{
 for(const bad of [{...draft,accent:'#ffffff'},{...draft,logo:'invented.svg'},{...draft,labels:{admin:'Unrestricted'}},{...draft,order:['tasks','tasks']},{...draft,blocks:[{id:'unsafe',kind:'link',title:'Unsafe',body:'Click',href:'javascript:alert(1)'}]},{...draft,blocks:[{id:'html',kind:'text',title:'Unsafe',body:'<script>run()</script>'}]}])expect(validSitePresentation(bad)).toBe(false)
 expect(()=>applyNavigationPresentation(getVisibleNavigation({audience:'core',capabilities:[]}),{...draft,accent:'#fff'})).toThrow()
 expect(validSitePresentation({...draft,labels:Object.create({tasks:'Hidden inherited label'})})).toBe(false)
})
it('P39_U1: optional PRISM and mentoring stay absent even if capabilities are present',()=>{
 const items=getVisibleNavigation({audience:'core',capabilities:['feedback.review','mentoring.view']})
 expect(items.some(x=>x.id==='feedback'||x.id==='mentoring')).toBe(false)
})
