import { useId, type ReactNode } from 'react'

export function PageHeading({ title, description }: { title: string; description?: string }) {
  return <header className="page-heading"><h1>{title}</h1>{description ? <p>{description}</p> : null}</header>
}

export function Panel({ title, children, className = '', id }: { title: string; children: ReactNode; className?: string; id?: string }) {
  const headingId = useId()
  return <section id={id} className={`panel ${className}`} aria-labelledby={headingId}><h2 id={headingId}>{title}</h2>{children}</section>
}
