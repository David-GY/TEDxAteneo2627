import { useId, type ReactNode } from 'react'

export function PageHeading({ title, description }: { title: string; description?: string }) {
  return <header className="page-heading"><h1>{title}</h1>{description ? <p>{description}</p> : null}</header>
}

export function Panel({ title, children, className = '' }: { title: string; children: ReactNode; className?: string }) {
  const id = useId()
  return <section className={`panel ${className}`} aria-labelledby={id}><h2 id={id}>{title}</h2>{children}</section>
}
