import {WorkingTogetherPage} from '../features/synergies/WorkingTogetherPage'
import {AgreementPage} from '../features/synergies/AgreementPage'
import {Overview} from '../features/overview/Overview'
import { createBrowserRouter, Link, redirect, type RouteObject } from 'react-router'
import { readClientEnvironment, type ClientEnvironment } from '../lib/env'
import { PageHeading, Panel } from '../components/Page'
import { EmptyState, ErrorState } from '../components/FeedbackState'
import { AppShell } from './AppShell'
import { TaskDetail } from '../features/tasks/TaskDetail'
import { TasksPage } from '../features/tasks/TasksPage'
import { navigationItems } from './navigation'
import { createAuthGateway, isGuest, type AuthGateway } from '../features/auth/gateway'
import { RedeemPage, SponsorPage } from '../features/guests/pages'
import { AccountPage, AuthRevalidator, CallbackPage, LoginPage, ProtectedShell } from '../features/auth/pages'
import { safeReturnPath, isDeliverablePath, isTaskPath } from '../features/auth/redirects'
import { DeliverablesRoute } from '../features/deliverables/DeliverablesPage'
import { DeliverablePage } from '../features/deliverables/DeliverablePage'
import { LoadingState } from '../components/FeedbackState'
import { DirectoryPage } from '../features/people/pages'

function FoundationPage({ environment }: { environment: ClientEnvironment }) {
  return (
    <>
      <PageHeading title="Overview" description="A focused view of your work and the people moving it forward." />
      <div className="overview-layout">
      <Panel title={environment.state === 'not_configured' ? 'Setup needed' : 'Configuration present'}>
        {environment.state === 'not_configured' ? (
          <>
            <p>The workspace is not connected to Supabase yet. You can continue local setup without signing in.</p>
            <ul>{environment.issues.map((issue) => <li key={issue}>{issue}</li>)}</ul>
          </>
        ) : (
          <p>Public configuration is valid. Sign-in and data access have not been implemented or verified.</p>
        )}
        <p className="muted">No member, task, financial or feedback records are being loaded.</p>
      </Panel>
      <Panel title="Find your next step">
        <p className="muted">Explore the workspace structure while setup is in progress.</p>
        <ul className="resource-links">
          <li><Link to="/deliverables">Core deliverables<span>Event outputs and accountable owners</span></Link></li>
          <li><Link to="/working-together">Working together<span>Committee contributions and handoffs</span></Link></li>
          <li><Link to="/resources">Resources & Start Here<span>Process guides and who to ask</span></Link></li>
        </ul>
      </Panel>
      </div>
      <EmptyState title="Your work will appear here" description="Once your account is connected and work is assigned, this overview will show your next actions. No sample tasks or metrics are shown." />
    </>
  )
}

function RouteErrorPage() {
  return (
    <main className="standalone-page">
      <h1>The workspace could not open</h1>
      <ErrorState title="This page could not be displayed" description="Try returning to the start. If this continues, contact the workspace maintainer." action={<a className="button" href="/">Return to start</a>} />
    </main>
  )
}

function NotFoundPage() {
  return (
    <>
      <PageHeading title="Page not found" />
      <p>This address does not point to a workspace page.</p>
      <Link className="button" to="/">Return to start</Link>
    </>
  )
}

export function createAppRoutes(environment: ClientEnvironment, gateway: AuthGateway = createAuthGateway(environment, window.location.origin)): RouteObject[] {
  return [
    { element: <AuthRevalidator gateway={gateway} />, errorElement: <RouteErrorPage />, hydrateFallbackElement: <main className="standalone-page"><LoadingState /></main>, children: [
      { path: '/login', loader: async ({ request }) => {
        const result = await gateway.readContext(request.signal)
        const returnTo=safeReturnPath(new URL(request.url).searchParams.get('returnTo'))
        return result.state === 'authorized' ? redirect(isGuest(result)&&!isDeliverablePath(returnTo)&&!isTaskPath(returnTo)?'/shared':returnTo) : result
      }, element: <LoginPage gateway={gateway} /> },
      { path: '/auth/callback', element: <CallbackPage gateway={gateway} /> },
      { path: '/guest/redeem', loader:({request})=>gateway.readContext(request.signal), element: <RedeemPage gateway={gateway} /> },
      ...(import.meta.env.DEV ? [{ path: '/preview', element: <AppShell />, children: [{ index: true, element: <FoundationPage environment={environment} /> }] }] : []),
      { id:'workspace', path: '/', element: <ProtectedShell />, loader: async ({ request }) => {
        const result = await gateway.readContext(request.signal)
        if (result.state === 'authorized') {
          const path=new URL(request.url).pathname
          if(isGuest(result) && !isDeliverablePath(path) && !isTaskPath(path) && !navigationItems.some(item=>item.href===path && item.audiences.includes('guest')))return redirect('/shared')
          if(path==='/guests' && !result.capabilities.includes('roles.manage'))return redirect(isGuest(result)?'/shared':'/')
          return result
        }
        const url = new URL(request.url)
        return redirect(`/login?reason=${result.state === 'denied' ? 'denied' : 'check'}&returnTo=${encodeURIComponent(safeReturnPath(url.pathname))}`)
      }, shouldRevalidate: () => true, children: [
      { index: true, element: gateway.overview?<Overview api={gateway.overview}/>:<><PageHeading title="Overview"/><EmptyState title="Overview unavailable" description="The workspace connection is unavailable."/></> },
      {path:'working-together/:agreementId',element:gateway.synergies?<AgreementPage api={gateway.synergies}/>:<EmptyState title="Agreement unavailable" description="The connection is unavailable."/>},
      {path:'tasks/:taskId',element:gateway.tasks?<TaskDetail api={gateway.tasks} comments={gateway.comments} files={gateway.files} synergies={gateway.synergies}/>:<EmptyState title="Task unavailable" description="The connection is unavailable."/>},
      {path:'deliverables/:deliverableId',element:gateway.deliverables?<DeliverablePage api={gateway.deliverables} commands={gateway.deliverableCommands} comments={gateway.comments} files={gateway.files} synergies={gateway.synergies}/>:<EmptyState title="Deliverable unavailable" description="The workspace connection is unavailable."/>},
      ...navigationItems.filter((item) => item.href !== '/').map((item) => ({
        path: item.href.slice(1),
        element: item.href === '/working-together' && gateway.synergies ? <WorkingTogetherPage api={gateway.synergies}/> : item.id === 'tasks' && gateway.tasks ? <TasksPage api={gateway.tasks} /> : item.id === 'deliverables' && gateway.deliverables ? <DeliverablesRoute api={gateway.deliverables} commands={gateway.deliverableCommands} /> : item.id === 'people' && gateway.people ? <DirectoryPage api={gateway.people} /> : item.id === 'guests' && gateway.guests ? <SponsorPage api={gateway.guests} /> : item.id === 'account' ? <AccountPage gateway={gateway} /> : <><PageHeading title={item.label} description={item.description} /><EmptyState title="This area is not connected yet" description="Its records and actions will become available after the relevant feature is implemented." action={<Link className="button button--secondary" to="/">Return to overview</Link>} /></>,
        errorElement: <ErrorState title="This page could not open" description="Return to the overview and try again. If it keeps happening, contact the workspace maintainer." action={<Link className="button" to="/">Return to overview</Link>} />,
      })),
      ] },
      { path: '*', element: <main className="standalone-page"><NotFoundPage /></main> },
    ] },
  ]
}

export function createAppRouter() {
  // Read only these explicit public variables, never the entire environment object.
  const environment = readClientEnvironment({
    VITE_SUPABASE_URL: import.meta.env.VITE_SUPABASE_URL,
    VITE_SUPABASE_PUBLISHABLE_KEY: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
  })
  return createBrowserRouter(createAppRoutes(environment))
}
