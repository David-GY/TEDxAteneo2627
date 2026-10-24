import { useEffect, useRef, useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { Panel } from '../../components/Page'
import { TextField } from '../../components/TextField'
import { LoadingState } from '../../components/FeedbackState'
import type { GuestContactGateway, GuestContactView } from './guestContacts'

export function GuestContactEditor({ api, termId }: { api: GuestContactGateway; termId: string }) {
  const [data, setData] = useState<GuestContactView | null>(null)
  const [name, setName] = useState('')
  const [contact, setContact] = useState('')
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [busy, setBusy] = useState(false)
  const [attempt, setAttempt] = useState(0)
  const pending = useRef<{ signature: string; id: string } | null>(null)
  useEffect(() => {
    let active = true
    void api.read(termId).then(result => {
      if (!active) return
      setData(result); setName(result.own.displayName); setContact(result.own.contactRoute ?? ''); pending.current = null
    }).catch(() => { if (active) setError('Your contacts could not load. Check your invitation access and reload.') })
    return () => { active = false }
  }, [api, termId, attempt])
  async function save(event: FormEvent) {
    event.preventDefault()
    if (!data || busy) return
    setBusy(true); setError(''); setNotice('')
    const values = { displayName: name || null, contactRoute: contact || null }
    const signature = JSON.stringify([termId, data.own.version, values])
    if (pending.current?.signature !== signature) pending.current = { signature, id: crypto.randomUUID() }
    try {
      const result = await api.save(termId, values, data.own.version, pending.current.id)
      setData(result); setName(result.own.displayName); setContact(result.own.contactRoute ?? '')
      pending.current = null; setNotice('Your contact details were saved. They have not been shared with other people.')
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'The save could not be confirmed. Please retry.') }
    finally { setBusy(false) }
  }
  return <Panel title="Your contacts">
    <p>Your guest access includes your own contact details and any contacts explicitly shared with your invitation.</p>
    <p><Link to="/shared">Shared with me</Link> · <Link to="/resources">Resources & Start Here</Link></p>
    {error ? <p role="alert">{error}</p> : null}{notice ? <p role="status">{notice}</p> : null}
    {!data && !error ? <LoadingState /> : null}
    {data ? <>
      <p>Verified Google email: {data.own.verifiedEmail}</p>
      <p>Only you can view these saved details here. Saving does not share them. Both fields are optional.</p>
      <form onSubmit={event => void save(event)}>
        <fieldset className="profile-fields" disabled={busy}>
          <legend>Your own details</legend>
          <TextField id="guest-contact-name" label="Display name" maxLength={200} value={name} onChange={event => setName(event.target.value)} autoComplete="off" />
          <TextField id="guest-contact-route" label="Preferred contact route" maxLength={320} value={contact} onChange={event => setContact(event.target.value)} autoComplete="off" />
          <button className="button" type="submit">Save my contact details</button>
        </fieldset>
      </form>
      <h3>Shared contacts</h3>
      {data.sharedContacts.length ? <ul className="guest-list shared-contact-list">{data.sharedContacts.map(person => <li key={person.id}>
        <h4>{person.name}</h4>{person.organizationContact ? <a className="button button--secondary" href={`mailto:${encodeURIComponent(person.organizationContact)}`}>Email {person.name}</a> : <p>Organization contact not available</p>}
      </li>)}</ul> : <p>No other contacts are shared with this invitation. Ask the person who gave you the link for help.</p>}
    </> : null}
    <button className="button button--secondary" type="button" disabled={busy} onClick={() => { setData(null); setError(''); setNotice(''); setAttempt(attempt + 1) }}>Reload contacts and discard unsaved edits</button>
  </Panel>
}
