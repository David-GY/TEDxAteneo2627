import { useEffect, useState } from 'react'
import { Link, useRouteLoaderData } from 'react-router'
import { PageHeading, Panel } from '../../../components/Page'
import { isGuest, type WorkspaceContext } from '../../auth/gateway'
import type { BackupHealth, BackupState, ReadBackupHealth } from './api'
import '../privacy/privacy.css'

const labels: Record<BackupState, string> = {
  missing: 'No verification recorded', started: 'Verification in progress', interrupted: 'Verification interrupted',
  verified: 'Verified', failed: 'Verification failed', blocked: 'Verification blocked',
  stale: 'Backup is older than 24 hours', pending: 'Current backup still needs a restore check',
}
const actions = {
  device: 'Reconnect the approved backup device.',
  provider: 'Confirm the approved provider is available and the operator has access.',
  key: 'Ask the separate key custodian to make the recovery key available.',
  ledger: 'Reconcile the current disposition ledger before opening restored data.',
  target: 'Confirm a fresh isolated recovery target.',
  custody: 'Confirm the current designated operator and independent reviewer.',
}
const format = (value: string | null) => value
  ? new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Manila' }).format(new Date(value)) + ' Manila time'
  : 'None recorded'

export function BackupHealthPage({ read }: { read: ReadBackupHealth }) {
  const context = useRouteLoaderData('workspace') as WorkspaceContext
  if (isGuest(context)) return <p role="alert">Current recovery custody is required.</p>
  return <Health key={context.termId + ':' + context.termMembershipId} term={context.termId} read={read} />
}

function Health({ term, read }: { term: string; read: ReadBackupHealth }) {
  const [loaded, setLoaded] = useState<{ data: BackupHealth; request: number; elapsed: number } | null>(null)
  const [state, setState] = useState<'checking' | 'ready' | 'denied' | 'error'>('checking')
  const [request, setRequest] = useState(0)
  const data = loaded?.request === request ? loaded.data : null

  useEffect(() => {
    let current = true
    setLoaded(null)
    setState('checking')
    const startedAt = performance.now()
    void read(term).then(result => {
      if (current) {
        setLoaded({ data: result, request, elapsed: performance.now() - startedAt })
        setState('ready')
      }
    }).catch(error => {
      if (current) setState(error?.code === '42501' ? 'denied' : 'error')
    })
    return () => { current = false }
  }, [read, term, request])

  useEffect(() => {
    const refresh = () => setRequest(n => n + 1)
    window.addEventListener('focus', refresh)
    return () => window.removeEventListener('focus', refresh)
  }, [])

  useEffect(() => {
    if (!loaded?.data.backupFreshUntil) return
    const remaining = Date.parse(loaded.data.backupFreshUntil) - Date.parse(loaded.data.checkedAt) - loaded.elapsed
    const timeout = window.setTimeout(() => {
      setLoaded(current => current === loaded ? { ...current, data: {
        ...current.data, backupStatus: 'stale', backupFreshUntil: null, restoreEvidence: null,
        restoreStatus: current.data.restoreStatus === 'verified' ? 'pending' : current.data.restoreStatus,
      } } : current)
    }, Math.max(0, remaining))
    return () => window.clearTimeout(timeout)
  }, [loaded])

  return <section className="privacy-editor">
    <PageHeading title="Backup and recovery health" description="Check the latest verified backup and see what recovery still needs." />
    <Link to="/admin/privacy">Privacy custodian tools</Link>
    <div><button type="button" className="button button--secondary" onClick={() => setRequest(n => n + 1)}>Refresh recovery status</button></div>
    {state === 'checking' && <p role="status">Checking current recovery evidence…</p>}
    {state === 'denied' && <p role="alert">Current recovery custody is required.</p>}
    {state === 'error' && <p role="alert">Recovery status is unavailable. Check the connection and refresh.</p>}
    {data && <>
      <Panel title="Encrypted backup">
        <p role="status">{labels[data.backupStatus]}</p>
        {data.backupBlocker ? <p>{actions[data.backupBlocker]}</p>
          : data.backupStatus !== 'verified' && <p>Ask the recovery operator to verify a current encrypted copy and record the result.</p>}
        <p>Last verified backup · {format(data.lastVerifiedBackupAt)}</p>
        <p>Latest backup attempt · {format(data.lastBackupAttemptAt)}</p>
      </Panel>
      <Panel title="Isolated restore">
        <p role="status">{labels[data.restoreStatus]}</p>
        <p>Latest restore attempt · {format(data.lastRestoreAttemptAt)}</p>
        {data.restoreBlocker && <p>{actions[data.restoreBlocker]}</p>}
        {data.restoreStatus !== 'verified' && <p>Use an isolated target and verify identity scope, private files and disposition replay before reporting success.</p>}
      </Panel>
      <details>
        <summary>Verification details</summary>
        <p>Evidence checked · {format(data.checkedAt)}</p>
        {data.backupEvidence && <p>Backup evidence fingerprint · <code>{data.backupEvidence}</code></p>}
        {data.restoreEvidence && <p>Restore evidence fingerprint · <code>{data.restoreEvidence}</code></p>}
        <Link to="/admin/privacy/disposition">Review the disposition ledger</Link>
      </details>
    </>}
  </section>
}
