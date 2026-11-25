import { Link, useLocation } from 'react-router'
import { PageHeading, Panel } from '../components/Page'
import type { WorkspaceContext } from '../features/auth/gateway'
import type { OverviewRow } from '../features/overview/api'
import { OverviewLane } from '../features/overview/OverviewViews'
import { AppShell } from './AppShell'
import { getVisibleNavigation, type NavigationContext } from './navigation'

export const memberPreviewPath = '/member-preview'
export const isMemberPreviewPath = (path: string) => {
  const lower = path.toLowerCase()
  return lower === memberPreviewPath || lower.startsWith(memberPreviewPath + '/')
}
export function canPreviewAsMember(context: WorkspaceContext) {
  return 'memberId' in context && context.capabilities.includes('admin.configure')
}

const memberNavigation: NavigationContext = { audience: 'core', capabilities: [] }
const sampleTask: OverviewRow = {
  id: '307b8bad-6ac9-46ad-aca7-76ef4ea0b006',
  source: 'task',
  title: 'Confirm the stage rehearsal checklist',
  owner: 'Sample member',
  lane: 'actionable',
  action: 'Check the list with your committee head',
  person: 'Sample member',
  state: 'in_progress',
  committee: 'Stage Management',
  dueOn: '2027-04-14',
  dueAt: null,
  overdue: false,
}

const examples: Record<string, { title: string; detail: string }> = {
  deliverables: { title: 'Stage rehearsal plan', detail: 'Stage Management · In progress' },
  working: { title: 'Rehearsal cue sheet handoff', detail: 'Stage Management → Programs & Activities' },
  requests: { title: 'Request logistics support', detail: 'See the service details before starting a request.' },
  calendar: { title: 'Stage rehearsal', detail: 'April 14, 2027 · 3:00 PM Manila time' },
  resources: { title: 'New member guide', detail: 'Start with your committee’s checklist and contact.' },
  people: { title: 'Stage Management', detail: 'Sample member · Core' },
  publicity: { title: 'Final publicity', detail: 'No publicity items in this example.' },
  search: { title: 'Search permitted work', detail: 'Tasks, deliverables, and requests appear here when they match a search.' },
  notifications: { title: 'Task assigned', detail: 'Confirm the stage rehearsal checklist.' },
  account: { title: 'Sample member', detail: 'Stage Management Core' },
}

export function MemberPreview() {
  const path = useLocation().pathname.toLowerCase().slice(memberPreviewPath.length).replace(/\/$/, '') || '/'
  const active = getVisibleNavigation(memberNavigation).find(item => item.href === path)
  const overview = path === '/'
  const tasks = active?.id === 'tasks'
  const example = active ? examples[active.id] : undefined
  return <AppShell
    context={memberNavigation}
    identity={{ displayName: 'Sample member', unitName: 'Stage Management Core' }}
    preview={false}
    memberPreviewPath={memberPreviewPath}
    headerAction={<Link className="button" replace to="/admin">Return to admin view</Link>}
    content={<>
      <PageHeading title={active?.label ?? 'Preview page unavailable'} description={overview
        ? 'Your next actions and work waiting on someone else.' : active?.description} />
      {overview && <>
        <OverviewLane items={[sampleTask]} lane="actionable" illustrative />
        <div className="auth-actions">
          <Link className="button button--secondary" to={memberPreviewPath + '/tasks'}>My tasks</Link>
          <Link className="button button--secondary" to={memberPreviewPath + '/requests'}>Find a request service</Link>
          <Link className="button button--secondary" to={memberPreviewPath + '/resources'}>Resources &amp; Start Here</Link>
        </div>
      </>}
      {tasks && <Panel title="Assigned to me"><h3>{sampleTask.title}</h3><p>Stage Management · In progress · Due April 14, 2027</p></Panel>}
      {example && <Panel title={example.title}><p>{example.detail}</p></Panel>}
      {!active && <Link className="button button--secondary" to={memberPreviewPath}>Return to preview overview</Link>}
    </>}
  />
}
