// Presentation only. No widget accepts a query, capability, route or data payload.
export const widgetCatalog = [
 {id:'waiting',label:'Waiting on someone else',guest:true},
 {id:'tasks',label:'My tasks',guest:true},
 {id:'deliverables',label:'Core deliverables',guest:false},
 {id:'working',label:'Working together',guest:false},
 {id:'reviews',label:'Department requests and reviews',guest:false},
 {id:'calendar',label:'Upcoming dates',guest:true},
 {id:'resources',label:'Resources & Start Here',guest:true},
] as const
export type WidgetId=typeof widgetCatalog[number]['id']
