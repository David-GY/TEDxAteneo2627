import type {Action,AccessData,Values} from './api'

const permissions:Record<string,string>={'workspace.read':'Read permitted workspace work','directory.read':'View the member directory','profile.edit_own':'Edit your own profile','committee.manage':'Manage committee work','department.review':'Review department requests','finance.review':'Review financial plans (FIN)','mcd.review':'Review final publicity (MCD)','feedback.review':'Review confidential feedback','mentoring.view':'View your mentoring records','reports.view':'View permitted reports','admin.configure':'Configure the workspace','roles.manage':'Manage roles and access'}
export const permissionName=(key:string)=>permissions[key]??'Permission unavailable'
export const scopeName=(scope:string)=>({unit:'This committee',term:'This term',work:'This record',own:'Own records'} as Record<string,string>)[scope]??'Scope unavailable'
export const actionName=(action:Action)=>({role_publish:'Publish a role revision',assignment_grant:'Assign a published role',assignment_expiry:'Change an assignment expiry',assignment_revoke:'Revoke an assignment',custodian_nominate:'Nominate a replacement custodian',custodian_accept:'Accept my custody nomination'})[action]
export const accessDate=(value:string)=>Number.isFinite(Date.parse(value))?new Intl.DateTimeFormat('en-PH',{timeZone:'Asia/Manila',year:'numeric',month:'short',day:'numeric',hour:'numeric',minute:'2-digit'}).format(new Date(value))+' (Manila)':'Date unavailable'
export function namedScope(data:AccessData,scope:string,unitId:string|null,workId:string|null){
 if(scope==='unit'){const unit=data.units.find(u=>u.id===unitId);return unit?'This committee · '+unit.name:null}
 if(scope==='work'){const work=data.records.find(w=>w.id===workId);return work?'This record · '+work.name:null}
 return ['own','term'].includes(scope)?scopeName(scope):null
}
export function explainImpact(data:AccessData,action:Action,values:Values){
 const str=(key:string)=>typeof values[key]==='string'?values[key] as string:''
 const nomination=action==='custodian_accept'?data.nominations?.find(n=>n.id===str('nominationId')):null
 const assignment=data.assignments?.find(a=>a.id===(nomination?.assignmentId??str('assignmentId')))
 const role= data.roles.find(r=>r.id===(assignment?.roleId??str('roleId')))
 const person=data.targets.find(t=>t.id===(assignment?.membershipId??str('targetMembershipId')))
 const scope=namedScope(data,assignment?.scope??str('scope'),assignment?.unitId??str('unitId'),assignment?.workId??str('workId'))
 if(action==='role_publish'){
  const selected=Array.isArray(values.permissions)?values.permissions:[]
  if(!scope||!selected.length||selected.some(p=>!permissions[p.capability]))return null
  return {person:null,role:str('name'),scope,permissions:selected,from:null,to:null,previousExpiry:null,nominationExpiry:null,reference:null,impact:'Creates an immutable role revision. Existing assignments keep their published revision; this does not assign the role.'}
 }
 if(!assignment&&action!=='assignment_grant'||!person||!role||!scope)return null
 if(action==='custodian_accept'&&(!nomination||nomination.candidateId!==assignment?.membershipId))return null
 if(role.permissions.some(p=>!permissions[p.capability]||!['unit','term','work','own'].includes(p.scope)))return null
 return {person:person.name,role:role.name,scope,permissions:role.permissions,from:assignment?.from??str('from'),to:action==='assignment_expiry'||action==='assignment_grant'?str('to'):assignment?.to??null,previousExpiry:action==='assignment_expiry'?assignment?.to??null:null,nominationExpiry:nomination?.expiresAt??null,reference:action.startsWith('custodian_')?str('reference'):null,impact:action==='assignment_grant'?'Assigns only this published role within the reviewed scope and dates, subject to current independently approved delegation limits.':action==='assignment_expiry'?'Changes only this assignment expiry. All current source, delegation and membership limits still apply.':action==='assignment_revoke'?'Revokes this exact assignment. Dependent access is rechecked; an independently confirmed replacement must remain before removing protected custody.':action==='custodian_nominate'?'The named candidate must sign in independently and accept the current nomination before counting as replacement custody. Nomination alone does not confirm a replacement.':'Records your own independent acknowledgment of the current nomination. This confirms application custody only; provider ownership and institutional approval remain separate.'}
}
