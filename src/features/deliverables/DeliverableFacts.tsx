import type { Deliverable } from './api'
export function dateLabel(at: string | null, on: string | null): string {
  const date = at ?? (on ? on + 'T00:00:00+08:00' : null)
  if (!date || !Number.isFinite(Date.parse(date))) return 'Not set'
  return new Intl.DateTimeFormat('en-PH',{ timeZone:'Asia/Manila',year:'numeric',month:'short',day:'numeric',...(at ? {hour:'numeric' as const,minute:'2-digit' as const} : {}) }).format(new Date(date))
}
export function DeliverableFacts({ item }: { item: Deliverable }) {
  return <dl className="deliverable-facts">
    <div><dt>Accountable owner</dt><dd>{item.owner.name}{!item.owner.active ? <span className="muted"> · Reassignment needed</span> : null}</dd></div>
    <div><dt>Lead committee</dt><dd>{item.leadUnit?.name ?? 'Not set'}</dd></div>
    <div><dt>Contributing committees · planning</dt><dd>{item.supportingUnits.map(u=>u.name).join(' · ') || 'None recorded'}</dd></div>
    <div><dt>Target date</dt><dd>{dateLabel(item.dueAt,item.dueOn)}{item.overdue ? ' · Overdue' : ''}</dd></div>
    <div><dt>Readiness</dt><dd>{item.readiness === 'blocked_provisional' ? 'Blocked · provisional' : 'Pending gate verification'}</dd></div>
    <div><dt>Next action / person</dt><dd>{item.nextAction}<span className="muted"> {item.owner.active ? item.owner.name : 'Owner assignment needed'}</span></dd></div>
    <div><dt>Blockers</dt><dd>{item.blocked ? item.blocker ?? 'Reported blocker; ask the owner for details.' : 'No blocker recorded'}</dd></div>
    <div><dt>Required reviews</dt><dd>Finance: not assessed<br/>Final publicity: not assessed<br/>Acceptance: pending definition</dd></div>
    <div><dt>Last meaningful update</dt><dd><time dateTime={item.updatedAt}>{dateLabel(item.updatedAt,null)}</time></dd></div>
  </dl>
}
