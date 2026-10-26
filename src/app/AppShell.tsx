import {NotificationBadge} from '../features/notifications/Notifications'
import { useEffect, useRef, useState, type KeyboardEvent } from 'react'
import { Link, NavLink, Outlet, useLocation, useNavigation } from 'react-router'
import { LoadingState } from '../components/FeedbackState'
import { getMobilePrimaryNavigation, getVisibleNavigation, setupNavigation, type NavigationContext, type NavigationItem } from './navigation'

type AppShellProps = {
  context?: NavigationContext
  identity?: { displayName: string; unitName?: string }
  preview?: boolean
}

function PageLink({ item, compact = false }: { item: NavigationItem; compact?: boolean }) {
  const label = compact && item.id === 'deliverables' ? 'Deliverables' : item.label
  return <NavLink className="nav-link" to={item.href} end={item.href === '/'}>{label}</NavLink>
}

export function AppShell({ context = setupNavigation, identity, preview = true }: AppShellProps) {
  const location = useLocation()
  const navigation = useNavigation()
  const [moreOpen, setMoreOpen] = useState(false)
  const mainRef = useRef<HTMLElement>(null)
  const moreButtonRef = useRef<HTMLButtonElement>(null)
  const closeButtonRef = useRef<HTMLButtonElement>(null)
  const previousPath = useRef(location.pathname)
  const items = getVisibleNavigation(context)
  const primary = getMobilePrimaryNavigation(context)
  const more = items.filter((item) => !primary.some((entry) => entry.id === item.id))
  const current = items.find((item) => item.href === location.pathname)

  useEffect(() => {
    if (previousPath.current !== location.pathname) {
      previousPath.current = location.pathname
      setMoreOpen(false)
      mainRef.current?.focus()
    }
  }, [location.pathname])

  useEffect(() => { if (moreOpen) closeButtonRef.current?.focus() }, [moreOpen])

  function closeMore() {
    setMoreOpen(false)
    moreButtonRef.current?.focus()
  }

  function handleMoreKey(event: KeyboardEvent<HTMLElement>) {
    if (event.key === 'Escape') { event.preventDefault(); closeMore() }
  }

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to main content</a>
      {preview ? <div className="preview-notice">Development shell preview <span>Destinations require sign-in</span></div> : null}
      <div className="workspace-shell">
        <aside className="sidebar" aria-label="Workspace sidebar">
          <div className="workspace-identity">
            <Link to="/" className="text-identity">TEDx Ateneo de Manila U</Link>
            <p>Core workspace</p>
            <small>Text identity; approved logo pending</small>
          </div>
          <nav aria-label="Workspace navigation" className="desktop-navigation">
            {(['workspace', 'role', 'account'] as const).map((group) => {
              const entries = items.filter((item) => item.group === group)
              return entries.length ? <ul className={`navigation-group navigation-group--${group}`} key={group}>{entries.map((item) => <li key={item.id}><PageLink item={item} /></li>)}</ul> : null
            })}
          </nav>
          <div className="sidebar-footer"><p>One team. Clear next steps.</p><p className="muted">Event day<br /><time dateTime="2027-04-17">April 17, 2027</time></p></div>
        </aside>
        <div className="workspace-body">
          <header className="workspace-header">
            <div className="location-heading"><span className="mobile-identity">TEDxAteneodeManilaU</span><span>{current?.label ?? 'Core workspace'}</span></div>
            <div className="account-summary">
              {identity ? <div className="identity-details"><strong>{identity.displayName}</strong>{identity.unitName ? <span>{identity.unitName}</span> : null}</div> : <span className="muted">Not signed in</span>}
              <NotificationBadge/><Link className="button button--secondary" to="/account">Account</Link>
            </div>
          </header>
          <main className="workspace-main" id="main-content" tabIndex={-1} ref={mainRef} aria-busy={navigation.state !== 'idle'}>
            {navigation.state !== 'idle' ? <LoadingState /> : <Outlet />}
          </main>
        </div>
      </div>
      <section className="mobile-more" id="mobile-more-pages" aria-label="More workspace pages" hidden={!moreOpen} onKeyDown={handleMoreKey}>
        <div className="more-heading"><h2>More pages</h2><button className="button button--secondary" type="button" ref={closeButtonRef} onClick={closeMore}>Close pages</button></div>
        <nav aria-label="Additional workspace navigation"><ul>{more.map((item) => <li key={item.id}><PageLink item={item} /></li>)}</ul></nav>
      </section>
      <nav className="mobile-navigation" aria-label="Mobile workspace navigation" onKeyDown={handleMoreKey}>
        {primary.map((item) => <PageLink key={item.id} item={item} compact />)}
        <button ref={moreButtonRef} className={`nav-link more-button${moreOpen ? ' active' : ''}`} type="button" aria-expanded={moreOpen} aria-controls="mobile-more-pages" onClick={() => moreOpen ? closeMore() : setMoreOpen(true)}>More</button>
      </nav>
    </>
  )
}
