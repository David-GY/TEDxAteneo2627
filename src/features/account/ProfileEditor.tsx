import { useEffect, useRef, useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { Panel } from '../../components/Page'
import { TextField } from '../../components/TextField'
import { LoadingState } from '../../components/FeedbackState'
import type { OwnProfile, ProfileGateway, ProfileValues, ProfileVisibility } from './gateway'

const fields = [
  { value: 'course', share: 'shareCourse', label: 'Course', max: 200 },
  { value: 'yearLevel', share: 'shareYearLevel', label: 'Year level', max: 80 },
  { value: 'phone', share: 'sharePhone', label: 'Personal phone', max: 80 },
  { value: 'externalContact', share: 'shareExternalContact', label: 'Other contact route', max: 320 },
  { value: 'skills', share: 'shareSkills', label: 'Skills', max: 1000 },
  { value: 'pronunciation', share: 'sharePronunciation', label: 'Name pronunciation', max: 200 },
  { value: 'affiliation', share: 'shareAffiliation', label: 'Affiliation', max: 80 },
] as const
export function ProfileEditor({ api, termId }: { api: ProfileGateway; termId: string }) {
  const [current, setCurrent] = useState<OwnProfile | null>(null)
  const [values, setValues] = useState<ProfileValues>({ course: null, yearLevel: null, phone: null, externalContact: null, skills: null, pronunciation: null, affiliation: null })
  const [visibility, setVisibility] = useState<ProfileVisibility>({ shareCourse: false, shareYearLevel: false, sharePhone: false, shareExternalContact: false, shareSkills: false, sharePronunciation: false, shareAffiliation: false })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [reload, setReload] = useState(0)
  const pending = useRef<{ signature: string; id: string } | null>(null)
  useEffect(() => {
    let active = true
    void api.read(termId).then(result => {
      if (!active) return
      setCurrent(result); setValues(result); setVisibility(result); pending.current = null
    }).catch(() => { if (active) setError('Your profile could not load. Check access and reload the profile.') })
    return () => { active = false }
  }, [api, termId, reload])
  async function save(event: FormEvent, command: 'values' | 'visibility') {
    event.preventDefault()
    if (!current || busy) return
    setBusy(true); setError(''); setNotice('')
    // Explicit whitelists keep server identity/version fields out of payloads.
    const privateValues: ProfileValues = { course: values.course, yearLevel: values.yearLevel, phone: values.phone, externalContact: values.externalContact, skills: values.skills, pronunciation: values.pronunciation, affiliation: values.affiliation }
    const choices: ProfileVisibility = { shareCourse: visibility.shareCourse, shareYearLevel: visibility.shareYearLevel, sharePhone: visibility.sharePhone, shareExternalContact: visibility.shareExternalContact, shareSkills: visibility.shareSkills, sharePronunciation: visibility.sharePronunciation, shareAffiliation: visibility.shareAffiliation }
    const signature = JSON.stringify([termId, command, current.version, command === 'values' ? privateValues : choices])
    if (pending.current?.signature !== signature) pending.current = { signature, id: crypto.randomUUID() }
    try {
      const result = command === 'values' ? await api.save(termId, privateValues, current.version, pending.current.id) : await api.share(termId, choices, current.version, pending.current.id)
      setCurrent(result)
      if (command === 'values') setValues(result); else setVisibility(result)
      pending.current = null
      setNotice(command === 'values' ? 'Private details saved. Your sharing choices were kept.' : 'Sharing choices saved. Unchecked details are hidden from the directory.')
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'The save could not be confirmed. Try again.') }
    finally { setBusy(false) }
  }
  return <Panel title="Your private profile">
    <p>All fields are optional. You can continue your work and find help with these blank. Heads cannot change your sharing choices.</p>
    <p><Link to="/resources">Resources & Start Here</Link> · <Link to="/people">Find a process contact</Link></p>
    {error ? <p role="alert">{error}</p> : null}{notice ? <p role="status">{notice}</p> : null}
    {!current && !error ? <LoadingState /> : null}
    {current ? <>
      <form onSubmit={event => void save(event, 'values')}>
        <fieldset className="profile-fields" disabled={busy}>
          <legend>Private details</legend>
          <p className="muted">Saving changes to a shared field updates what directory members can see. Use sharing choices below to hide it.</p>
          {fields.map(field => <TextField key={field.value} id={`profile-${field.value}`} label={field.label} hint={field.value === 'affiliation' ? 'Optional description for this term. MEAn affiliation does not change your role or access.' : undefined} maxLength={field.max} value={values[field.value] ?? ''} onChange={event => setValues({ ...values, [field.value]: event.target.value || null })} autoComplete="off" />)}
          <button className="button" type="submit">Save private details</button>
        </fieldset>
      </form>
      <form onSubmit={event => void save(event, 'visibility')}>
        <fieldset className="profile-fields profile-sharing" disabled={busy}>
          <legend>Directory sharing</legend>
          <p className="muted">Checked fields are shared with permitted core directory members. Uncheck and save to withdraw sharing.</p>
          {fields.map(field => <label key={field.share}><input type="checkbox" checked={visibility[field.share]} onChange={event => setVisibility({ ...visibility, [field.share]: event.target.checked })} />Share {field.label.toLowerCase()}</label>)}
          <button className="button" type="submit">Save sharing choices</button>
        </fieldset>
      </form>
    </> : null}
    <button className="button button--secondary" type="button" disabled={busy} onClick={() => { setCurrent(null); setError(''); setNotice(''); setReload(reload + 1) }}>Reload profile and discard unsaved edits</button>
  </Panel>
}
