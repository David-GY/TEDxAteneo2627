import type { InputHTMLAttributes } from 'react'

type TextFieldProps = InputHTMLAttributes<HTMLInputElement> & { id: string; label: string; hint?: string; error?: string }

export function TextField({ id, label, hint, error, 'aria-describedby': describedBy, ...inputProps }: TextFieldProps) {
  const descriptions = [describedBy, hint ? `${id}-hint` : '', error ? `${id}-error` : ''].filter(Boolean).join(' ')
  return (
    <div className="form-field">
      <label htmlFor={id}>{label}{inputProps.required ? ' (required)' : ''}</label>
      {hint ? <p id={`${id}-hint`} className="field-hint">{hint}</p> : null}
      <input {...inputProps} id={id} aria-describedby={descriptions || undefined} aria-invalid={error ? true : undefined} />
      {error ? <p className="field-error" id={`${id}-error`}>{error}</p> : null}
    </div>
  )
}
