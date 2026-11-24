import { useLayoutEffect, useRef, useState } from 'react'
import { isGuest, type WorkspaceContext } from '../auth/gateway'
import type { OperationalExport, OperationalKind } from './operational'
import { downloadCsv } from './downloadCsv'

type Props = { api?: OperationalExport; context: WorkspaceContext; kind: OperationalKind }

export function WorkCsvDownload({ api, context, kind }: Props) {
  if (!api || isGuest(context) || !context.capabilities.includes('workspace.read')) return null
  const scope = JSON.stringify([context.memberId, context.termMembershipId, context.termId, context.expiresAt, context.capabilities, kind])
  return <Download key={scope} api={api} term={context.termId} kind={kind} />
}

function Download({ api, term, kind }: { api: OperationalExport; term: string; kind: OperationalKind }) {
  const current = useRef(false)
  const inFlight = useRef(false)
  const [status, setStatus] = useState({ busy: false, error: false, text: '' })
  useLayoutEffect(() => {
    current.current = true
    return () => { current.current = false }
  }, [])

  async function download() {
    if (inFlight.current) return
    inFlight.current = true
    setStatus({ busy: true, error: false, text: 'Checking current access and preparing the CSV…' })
    try {
      const csv = await api(term, kind)
      if (!current.current) return
      if (csv === null) {
        setStatus({ busy: false, error: false, text: 'No eligible records to download in this term.' })
        return
      }
      downloadCsv(csv, 'tedx-' + kind + 's.csv')
      setStatus({ busy: false, error: false, text: 'CSV download requested.' })
    } catch (error) {
      if (current.current) setStatus({ busy: false, error: true, text: error instanceof Error && error.message ? error.message : 'The CSV could not be prepared. Try again.' })
    } finally {
      inFlight.current = false
    }
  }

  const label = kind === 'task' ? 'tasks' : 'deliverables'
  return <section aria-label={label + ' CSV export'}>
    <button type="button" className="button button--secondary" disabled={status.busy} onClick={() => void download()}>
      Download permitted {label} CSV
    </button>
    <p className="muted">Ordinary {label} you can access in this term, across list filters.</p>
    {status.text && <p role={status.error ? 'alert' : 'status'}>{status.text}</p>}
  </section>
}
