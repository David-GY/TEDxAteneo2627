export type NavigationAudience = 'setup' | 'core' | 'guest'

export type NavigationCapability =
  | 'committee.manage'
  | 'department.review'
  | 'finance.review'
  | 'mcd.review'
  | 'feedback.review'
  | 'mentoring.view'
  | 'reports.view'
  | 'admin.configure'
  | 'roles.manage'

export type NavigationContext = {
  audience: NavigationAudience
  capabilities: readonly NavigationCapability[]
}

export type NavigationItem = {
  id: string
  label: string
  href: string
  description: string
  group: 'workspace' | 'role' | 'account'
  audiences: readonly NavigationAudience[]
  capability?: NavigationCapability
}

export const setupNavigation: NavigationContext = { audience: 'setup', capabilities: [] }

export const navigationItems: readonly NavigationItem[] = [
  { id: 'overview', label: 'Overview', href: '/', description: 'Your next actions and the people moving work forward.', group: 'workspace', audiences: ['setup', 'core'] },
  { id: 'deliverables', label: 'Core deliverables', href: '/deliverables', description: 'Event outputs, accountable owners and required contributions.', group: 'workspace', audiences: ['setup', 'core'] },
  { id: 'shared', label: 'Shared with me', href: '/shared', description: 'Work explicitly shared with your guest account.', group: 'workspace', audiences: ['guest'] },
  { id: 'tasks', label: 'My tasks', href: '/tasks', description: 'Your assignments, deadlines and progress.', group: 'workspace', audiences: ['setup', 'core', 'guest'] },
  { id: 'working', label: 'Working together', href: '/working-together', description: 'Committee contributions, shared work, handoffs and timeline.', group: 'workspace', audiences: ['setup', 'core'] },
  { id: 'requests', label: 'Department requests', href: '/requests', description: 'Find the right support and track the next action on a request.', group: 'workspace', audiences: ['setup', 'core'] },
  { id: 'calendar', label: 'Calendar', href: '/calendar', description: 'Dates and events you are permitted to see.', group: 'workspace', audiences: ['setup', 'core', 'guest'] },
  { id: 'resources', label: 'Resources & Start Here', href: '/resources', description: 'Process guides, shared resources and who to ask.', group: 'workspace', audiences: ['setup', 'core', 'guest'] },
  { id: 'people', label: 'People', href: '/people', description: 'Committee contacts and the permitted member directory.', group: 'workspace', audiences: ['setup', 'core'] },
  { id: 'committee', label: 'My committee', href: '/committee', description: 'Work and contributions for your assigned committee.', group: 'role', audiences: ['core'], capability: 'committee.manage' },
  { id: 'department', label: 'Department inbox', href: '/department', description: 'Requests assigned to your department scope.', group: 'role', audiences: ['core'], capability: 'department.review' },
  { id: 'publicity', label: 'Final publicity', href: '/publicity', description: 'Frozen final publicity and independent MCD review.', group: 'role', audiences: ['core'] },
  { id: 'finance', label: 'FIN desk', href: '/finance', description: 'Financial cases within your explicit review authority.', group: 'role', audiences: ['core'], capability: 'finance.review' },
  { id: 'feedback', label: 'PRISM desk', href: '/feedback', description: 'Evaluation cases explicitly assigned to you.', group: 'role', audiences: ['core'], capability: 'feedback.review' },
  { id: 'mentoring', label: 'Mentoring', href: '/mentoring', description: 'Goals and check-ins for assigned mentoring relationships.', group: 'role', audiences: ['core'], capability: 'mentoring.view' },
  { id: 'reports', label: 'Reports', href: '/reports', description: 'Operational reports within your permitted scope.', group: 'role', audiences: ['core'], capability: 'reports.view' },
  { id: 'admin', label: 'Administration', href: '/admin', description: 'Workspace configuration for authorized administrators.', group: 'role', audiences: ['core'], capability: 'admin.configure' },
  { id: 'guests', label: 'Guest invitations', href: '/guests', description: 'Manage invitations you sponsor and their expiry.', group: 'role', audiences: ['core'], capability: 'roles.manage' },
  { id: 'search', label: 'Find work', href: '/search', description: 'Search permitted work titles and references.', group: 'account', audiences: ['core'] },
  { id: 'notifications', label: 'Notifications', href: '/notifications', description: 'Updates that need your attention.', group: 'account', audiences: ['setup', 'core', 'guest'] },
  { id: 'account', label: 'Account', href: '/account', description: 'Your profile and account settings.', group: 'account', audiences: ['setup', 'core', 'guest'] },
]

// Presentation only. Database/route authorization must be enforced separately.
export function getVisibleNavigation(context: NavigationContext): NavigationItem[] {
  return navigationItems.filter((item) => item.audiences.includes(context.audience)
    && !['feedback','mentoring'].includes(item.id)
    && (!item.capability || context.capabilities.includes(item.capability)))
}

export function getMobilePrimaryNavigation(context: NavigationContext): NavigationItem[] {
  const ids = context.audience === 'guest'
    ? ['shared', 'tasks', 'calendar', 'resources']
    : ['overview', 'deliverables', 'tasks', 'working']
  return getVisibleNavigation(context).filter((item) => ids.includes(item.id))
}
