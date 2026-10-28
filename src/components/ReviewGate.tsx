import {Panel} from './Page'
export type ReviewApplicability='not_required'|'pending_assessment'|'verified'|'pending'
// Applicability must come from an authorized projection, never a task type or hidden panel.
export function ReviewGate({title,status,applicability,loading}:{title:string;status:string|null;applicability?:ReviewApplicability;loading:boolean}){
 const label=loading?'Checking…':status==='authorized'||status==='reviewed'?'Current':status==='pending'||status==='not_verified'&&applicability==='pending'?'Pending':status==='not_verified'&&applicability==='not_required'?'Not required':'Unavailable'
 return <Panel title={title}><p role="status">{title}: {label}</p>{label==='Unavailable'?<p>Current review requirements or evidence could not be confirmed. Refresh this work before relying on a review.</p>:null}<p>Task completion does not grant approval, confirm payment or accept the deliverable. Private review details are not shared here.</p></Panel>
}
