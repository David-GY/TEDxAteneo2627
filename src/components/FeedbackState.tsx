import { useId, type ReactNode } from 'react'

type FeedbackProps = { title: string; description: string; action?: ReactNode }

export function EmptyState({ title, description, action }: FeedbackProps) {
  const id = useId()
  return <section className="feedback-state" aria-labelledby={id}><h2 id={id}>{title}</h2><p>{description}</p>{action}</section>
}

export function ErrorState({ title, description, action }: FeedbackProps) {
  const id = useId()
  return <section className="feedback-state feedback-state--error" aria-labelledby={id} role="alert"><h2 id={id}>{title}</h2><p>{description}</p>{action}</section>
}

export function LoadingState({ title = 'Opening workspace page' }: { title?: string }) {
  return <div className="feedback-state" role="status" aria-live="polite"><p>{title}</p><p className="muted">Please wait while this page opens.</p></div>
}
