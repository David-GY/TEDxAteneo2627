import { useEffect, useState } from 'react'
import { Link, useRouteLoaderData } from 'react-router'
import type { WorkspaceContext } from '../auth/gateway'
import { PageHeading, Panel } from '../../components/Page'
import { EmptyState, ErrorState, LoadingState } from '../../components/FeedbackState'
import { TextField } from '../../components/TextField'
import type { PeopleGateway } from './gateway'

export function DirectoryPage({ api }: { api: PeopleGateway }) {
  const context = useRouteLoaderData('workspace') as WorkspaceContext
  return <PeoplePage key={context.termId} api={api} termId={context.termId} />
}

export function PeoplePage({ api, termId }: { api: PeopleGateway; termId: string }) {
  const [data, setData] = useState<Awaited<ReturnType<PeopleGateway['read']>> | null>(null)
  const [error, setError] = useState(false)
  const [attempt, setAttempt] = useState(0)
  const [search, setSearch] = useState('')
  useEffect(() => {
    let active = true
    void api.read(termId).then(result => { if (active) setData(result) }).catch(() => { if (active) setError(true) })
    return () => { active = false }
  }, [api, termId, attempt])
  const query = search.trim().toLocaleLowerCase()
  const people = data?.people.filter(person => [person.name, ...person.units, ...person.roles].some(text => text.toLocaleLowerCase().includes(query))) ?? []
  return <>
    <PageHeading title="People" description="Find a process contact or a member by name, unit or role. Optional details appear only when shared." />
    <p><Link to="/resources">Resources & Start Here</Link> · <Link to="/tasks">My tasks</Link></p>
    <p className="muted">Affiliation and personal contact details are optional. You can find help and continue your work with these fields blank.</p>
    {error ? <ErrorState title="Directory unavailable" description="Your access may have changed, or the service could not respond." action={<button className="button" onClick={() => { setError(false); setData(null); setAttempt(attempt + 1) }}>Try again</button>} /> : !data ? <LoadingState /> : <>
      <Panel title="Who to ask">
        {data.processes.length ? <ul className="guest-list">{data.processes.map(process => <li key={process.id}>
          <h3>{process.name}</h3>
          <p>Primary: {process.primary.length ? process.primary.map(p => p.name).join(', ') : 'Not assigned — ask your unit head to confirm a contact.'}</p>
          <p>Backup: {process.backup.length ? process.backup.map(p => p.name).join(', ') : 'Not assigned — ask the primary contact for cover.'}</p>
        </li>)}</ul> : <p>No process contacts are available. The approved roster and contact assignments still need to be confirmed.</p>}
      </Panel>
      <Panel title="Member directory">
        <TextField id="people-search" label="Search people" hint="Search by name, unit or role." type="search" value={search} onChange={event => setSearch(event.target.value)} />
        <p role="status">{people.length} {people.length === 1 ? 'person' : 'people'} found</p>
        {people.length ? <ul className="guest-list">{people.map(person => <li key={person.id}>
          <h3>{person.name}</h3><p>{person.units.join(' · ') || 'Unit not assigned'}</p>
          <p>{person.roles.join(' · ') || 'Role not assigned'}</p>
          {person.contact ? <a className="button button--secondary" href={`mailto:${person.contact}`}>Email {person.name}</a> : <p>Organization contact not available</p>}
          {person.course ? <p>Course: {person.course}</p> : null}{person.year ? <p>Year: {person.year}</p> : null}
          {person.phone ? <p>Shared phone: {person.phone}</p> : null}{person.externalContact ? <p>Shared contact: {person.externalContact}</p> : null}
        </li>)}</ul> : <EmptyState title="No people found" description="Try another name, unit or role. Only permitted active members appear here." />}
      </Panel>
    </>}
  </>
}
