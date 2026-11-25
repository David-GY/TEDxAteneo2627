import { useState, type FormEvent } from 'react'
import { Panel } from '../../../components/Page'
import { TextField } from '../../../components/TextField'
import { useFinDecision } from '../../finance/DecisionMemory'
import type { OrganizationApi, OrganizationData } from './api'
import type { Position, Seat, SeatChange } from './positions'

type Selection = { seat: Seat | null; remove: boolean }
const manilaInput = (date: string) => new Date(Date.parse(date) + 8 * 3_600_000).toISOString().slice(0, 16)
const manilaDisplay = new Intl.DateTimeFormat('en-PH', { timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short' })
const roleLabel = (role: Position) => role.name + (role.administrator ? ' · Admin access' : '') + (!role.available ? ' · Archived' : '')

export function CommitteeRoles({ api, data, term, identity, refresh }: {
  api: OrganizationApi; data: OrganizationData; term: string; identity: string; refresh: () => void
}) {
  const [selection, setSelection] = useState<Selection | null>(null)
  const [roleFilter, setRoleFilter] = useState('')
  const roster = data.positionRoster
  if (!api.saveSeat || roster === undefined) return null
  if (!roster) return <Panel title="Committee roles"><p role="status">Roles could not be loaded. Refresh organization to try again.</p></Panel>
  if (!roster.positions.length) return null

  const { positions, seats } = roster
  const visibleSeats = seats.filter(seat => !roleFilter || seat.roleId === roleFilter)
  const canEdit = data.canPublish && !selection
  const hasMembers = data.members.some(member => member.state === 'active' && ['active', 'invited'].includes(member.accountState))

  return <Panel title="Committee and leadership roles">
    <p>Assign people from the approved roster. Heads manage their own committee. VP HRTD, PMs and WebDev Heads also receive workspace administration.</p>
    <div className="auth-actions committee-role-controls">
      <button className="button" disabled={!canEdit || !hasMembers} onClick={() => setSelection({ seat: null, remove: false })}>Assign a role</button>
      <label>Filter by role<select value={roleFilter} onChange={event => setRoleFilter(event.target.value)}>
        <option value="">All roles</option>
        {positions.map(role => <option key={role.id} value={role.id}>{roleLabel(role)}</option>)}
      </select></label>
    </div>
    {!hasMembers && <p>Add a member to the approved roster below before assigning their first role.</p>}
    {selection && data.canPublish && <RoleEditor key={selection.seat?.id ?? 'new'} save={api.saveSeat}
      data={data} positions={positions} selection={selection} term={term} identity={identity} initialRole={roleFilter}
      close={() => setSelection(null)} saved={() => { setSelection(null); refresh() }} />}
    {visibleSeats.length ? <ul className="organization-list">{visibleSeats.map(seat => {
      const member = data.members.find(person => person.id === seat.membershipId)
      const role = positions.find(position => position.id === seat.roleId)
      if (!member || !role) return null
      return <li key={seat.id}>
        <h3>{member.name} · {role.name}</h3>
        <p>{seat.state}{role.administrator ? ' · Admin access' : ''} · {manilaDisplay.format(new Date(seat.from))} to {manilaDisplay.format(new Date(seat.to))}</p>
        {seat.managed ? <div className="auth-actions">
          <button className="button button--secondary" disabled={!canEdit} onClick={() => setSelection({ seat, remove: false })}>Edit role</button>
          <button className="button button--secondary" disabled={!canEdit} onClick={() => setSelection({ seat, remove: true })}>Remove role</button>
        </div> : <p>Another administrator can edit this administrator assignment.</p>}
      </li>
    })}</ul> : <p>No assignments for this selection.</p>}
  </Panel>
}

function RoleEditor({ save, data, positions, selection, term, identity, initialRole, close, saved }: {
  save: NonNullable<OrganizationApi['saveSeat']>; data: OrganizationData; positions: Position[]; selection: Selection
  term: string; identity: string; initialRole: string; close: () => void; saved: () => void
}) {
  const { seat, remove } = selection
  const [reviewed, setReviewed] = useState(false)
  const command = useFinDecision<SeatChange, { id: string; version: number }>(
    { run: save }, term + ':seat:' + (seat?.id ?? 'new') + ':' + (remove ? 'remove' : 'edit'),
    { member: seat?.membershipId ?? '', role: seat?.roleId ?? initialRole, from: seat ? manilaInput(seat.from) : '',
      to: seat ? manilaInput(seat.to) : '', reason: '' },
  )
  const f = command.fields
  const members = data.members.filter(member => member.id === seat?.membershipId
    || member.state === 'active' && ['active', 'invited'].includes(member.accountState))
  const member = members.find(person => person.id === f.member)
  const role = positions.find(position => position.id === f.role)
  const instant = (value: string, original?: string) => original && value === manilaInput(original) ? original : value + ':00+08:00'
  const from = instant(f.from, seat?.from)
  const to = instant(f.to, seat?.to)
  const canSave = remove || (member && role?.available && (!role.administrator || member.memberId !== identity)
    && Date.parse(from) < Date.parse(to))

  function change(fields: Record<string, string>) {
    command.change({ ...f, ...fields })
    setReviewed(false)
  }

  function chooseMember(id: string) {
    const next = members.find(person => person.id === id)
    const start = next ? new Date(Math.max(Math.ceil(Date.now() / 60_000) * 60_000, Date.parse(next.joinedAt))) : null
    change({ member: id, from: start ? manilaInput(start.toISOString()) : '', to: next ? manilaInput(next.endsAt) : '' })
  }

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (command.pending) {
      if (await command.run()) saved()
      return
    }
    if (!reviewed || !canSave || !f.reason.trim()) return
    if (await command.run({ term, seat, membershipId: f.member, roleId: f.role, from, to, reason: f.reason.trim(), remove })) saved()
  }

  return <form className="organization-editor" onSubmit={event => void submit(event)}>
    <h3>{remove ? 'Remove assignment' : seat ? 'Edit assignment' : 'Assign a committee or leadership role'}</h3>
    <fieldset disabled={command.locked} className="organization-editor">
      {remove ? <p>Remove {role?.name} from {member?.name}. Their other roles stay in place.</p> : <>
        <label>Member<select required value={f.member} disabled={!!seat} onChange={event => chooseMember(event.target.value)}>
          <option value="">Choose an approved member</option>
          {members.map(person => <option key={person.id} value={person.id}>{person.name} ({person.email})</option>)}
        </select></label>
        <label>Role<select required value={f.role} onChange={event => change({ role: event.target.value })}>
          <option value="">Choose a role</option>
          {positions.map(position => <option key={position.id} value={position.id}
            disabled={!position.available || position.administrator && member?.memberId === identity}>{roleLabel(position)}</option>)}
        </select></label>
        <TextField id="seat-from" label="Starts · Manila time" type="datetime-local" required value={f.from} onChange={event => change({ from: event.target.value })} />
        <TextField id="seat-to" label="Ends · Manila time" type="datetime-local" required value={f.to} onChange={event => change({ to: event.target.value })} />
        {role?.administrator && <p>This role grants access to workspace Administration and role assignment.</p>}
      </>}
      <TextField id="seat-reason" label="Reason for change" required maxLength={1000} value={f.reason} onChange={event => change({ reason: event.target.value })} />
      <label><input type="checkbox" checked={reviewed} onChange={event => setReviewed(event.target.checked)} /> I reviewed this assignment change.</label>
    </fieldset>
    {command.error && <p role="alert">{command.error}</p>}
    <div className="auth-actions">
      <button className="button" type="submit" disabled={command.busy || !command.pending && (!reviewed || !canSave || !f.reason.trim())}>
        {command.pending ? 'Retry the same change' : remove ? 'Remove assignment' : 'Save assignment'}
      </button>
      <button className="button button--secondary" type="button" disabled={command.locked} onClick={close}>Cancel</button>
    </div>
  </form>
}
