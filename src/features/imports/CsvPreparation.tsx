import {useMemo,useState} from 'react'
import {Link,useRouteLoaderData} from 'react-router'
import {PageHeading,Panel} from '../../components/Page'
import {isGuest,type WorkspaceContext} from '../auth/gateway'
import {dryRun,fields,parseCsv,templates,type Kind,type Mapping} from './csv'
import './imports.css'

const labels:Record<string,string>={source_key:'source key',title:'title',assignee:'person responsible',committee:'committee',due_on:'due date',reference:'existing issued reference',display_name:'person’s name',email:'school email'}
const defaultMap=(kind:Kind):Mapping=>Object.fromEntries(fields[kind].map(field=>[field,field]))
export function CsvPreparation(){
  const context=useRouteLoaderData('workspace') as WorkspaceContext
  if(isGuest(context)||!['admin.configure','roles.manage'].every(c=>context.capabilities.includes(c)))return <><PageHeading title="CSV preparation unavailable"/><p>Current administration and roster-management permission is required. <Link to="/">Return to overview</Link>.</p></>
  return <Preparation key={context.termId+context.memberId+JSON.stringify(context.capabilities)}/>
}
function Preparation(){
  const [kind,setKind]=useState<Kind>('tasks'),[input,setInput]=useState(templates.tasks),[mapping,setMapping]=useState<Mapping>(defaultMap('tasks'))
  const [review,setReview]=useState<ReturnType<typeof dryRun>|null>(null)
  const parsed=useMemo(()=>{try{return {rows:parseCsv(input),error:''}}catch(e){return {rows:[],error:(e as Error).message}}},[input])
  const header=parsed.rows[0]??[]
  const ignored=header.filter(h=>!Object.values(mapping).includes(h))
  return <div className="csv-preparation"><PageHeading title="Prepare a CSV" description="Map columns and repair a small roster or task file before an authorized import is available."/>
    <p role="status">Preparation only: no people or work records are read or changed. Import and record export are unavailable.</p>
    <Panel title="1. Choose a template"><label>Preparation type<select value={kind} onChange={e=>{setKind(e.target.value as Kind);setMapping({});setReview(null)}}><option value="tasks">Ordinary tasks</option><option value="roster">Roster candidates</option></select></label>
      <p>Keep a unique source key for each row across retries. Use known people and committee names. An existing reference is a lookup hint only; new work will receive its reference from the server. Roster candidates never approve an account or grant a role. Financial work requires its separate authorized workflow.</p>
      <button className="button button--secondary" onClick={()=>{setInput(templates[kind]);setMapping(defaultMap(kind));setReview(null)}}>Replace input with fictional example</button>
      <p>CSV stays in this page’s memory. Reloading, leaving this page or changing account/term clears it. No automatic server lookup or browser storage is used. Keep your original file for resuming later.</p>
      <label>CSV input<textarea rows={8} spellCheck={false} value={input} onChange={e=>{setInput(e.target.value);setReview(null)}}/></label>
      <p>UTF-8 comma-separated CSV with a header; up to 500 data records, 32 columns and 200,000 characters. Quoted cells may contain commas and newlines. Record numbers include the header, regardless of embedded line breaks.</p>
      {parsed.error?<p role="alert">{parsed.error} Your input and mapping are kept for repair.</p>:null}
    </Panel>
    <Panel title="2. Map named columns"><p>Select a source column for each destination. Leave optional destinations unmapped. Source key and title are required for tasks; source key, person’s name and school email are required for roster candidates.</p>
      <div className="csv-mapping">{fields[kind].map(field=><label key={field}>Source for {labels[field]}<select aria-label={'Source for '+labels[field]} value={mapping[field]??''} onChange={e=>{setMapping({...mapping,[field]:e.target.value});setReview(null)}}><option value="">Not mapped</option>{mapping[field]&&!header.includes(mapping[field])?<option value={mapping[field]}>Missing: {mapping[field]}</option>:null}{header.map((h,i)=><option key={i} value={h}>{h||'(unnamed column)'}</option>)}</select></label>)}</div>
      <p>Ignored source columns: {ignored.join(', ')||'none'}. Authority and financial columns must be removed even when unmapped.</p>
      <button className="button" disabled={!!parsed.error||!input} onClick={()=>setReview(dryRun(kind,parsed.rows,mapping))}>Review mapped values</button>
    </Panel>
    {review?<Panel title="Mapped review"><p role="status">{review.valid?`Local validation passed for ${review.rows.length} ${review.rows.length===1?'record':'records'}. No records were imported.`:'Repair the errors below, then review again. The entire file is blocked while any error remains.'}</p>
      {review.errors.length?<ul role="alert">{review.errors.map((e,i)=><li key={i}>{e}</li>)}</ul>:null}
      <p>Before: unavailable until the server checks current scope, existing records and versions. Below are the exact proposed mapped values, not confirmed changes. People, committees and references have not been resolved. Blank values do not authorize clearing an existing field.</p>
      <div className="csv-review" tabIndex={0} role="region" aria-label="Mapped records"><table><thead><tr><th>CSV record</th>{fields[kind].map(f=><th key={f}>{labels[f]}</th>)}<th>Repair</th></tr></thead><tbody>{review.rows.map(row=><tr key={row.record}><th>{row.record}</th>{fields[kind].map(f=><td key={f}>{row.values[f]||'—'}</td>)}<td>{row.errors.length?<ul>{row.errors.map((e,i)=><li key={i}>{e}</li>)}</ul>:'Local checks passed; server review required'}</td></tr>)}</tbody></table></div>
    </Panel>:null}
    <Panel title="3. Server confirmation unavailable"><p>Import requires a scoped server dry-run, resolved identities, exact before/after changes, current permissions, expected versions and a durable retry key. Those interfaces are not connected. No import can be confirmed here. Record exports also require a server scope check before download.</p><button className="button" disabled>Import unavailable</button></Panel>
  </div>
}
