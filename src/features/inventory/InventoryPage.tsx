import {useCallback,useEffect,useRef,useState} from 'react'
import {Link,useParams,useRouteLoaderData,useSearchParams} from 'react-router'
import {PageHeading,Panel} from '../../components/Page'
import {TextField} from '../../components/TextField'
import {EmptyState,ErrorState,LoadingState} from '../../components/FeedbackState'
import type {WorkspaceContext} from '../auth/gateway'
import {forgetRecordDrafts} from '../auth/draftScope'
import {manilaDay} from '../timeline/dates'
import {InventoryEditor,type InventoryAction} from './InventoryEditor'
import type {InventoryApi,InventoryEntry,InventoryReceipt,InventoryWorkspace,Loan,StockItem} from './api'
import './inventory.css'

const loanStates={reserved:'Reserved',issued:'Physically issued',partial:'Partial return',complete:'Complete',cancelled:'Cancelled'}
const historyNames={reserve:'Reserved',issue:'Physically issued',consume:'Issued for consumption',return:'Returned to stock',
  damage:'Damaged · set aside',loss:'Reported lost',cancel:'Reservation cancelled'}
const conditions={usable:'Usable',worn:'Worn · still usable',damaged:'Damaged',missing:'Missing'}
const formatted=new Intl.DateTimeFormat('en-PH',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Manila'})
const details=(w:InventoryWorkspace,choice:InventoryAction)=>{
  const loan='loan'in choice?w.loans.find(l=>l.id===choice.loan):undefined
  return {loan,item:w.items.find(i=>i.id===('item'in choice?choice.item:loan?.itemId))}
}
const canIssue=(loan:Loan)=>{
  const today=manilaDay(new Date().toISOString())
  return loan.borrowerActive&&loan.startsOn<=today&&today<=loan.dueOn
}
const canUse=(w:InventoryWorkspace,choice:InventoryAction,loan?:Loan,item?:StockItem)=>{
  if(!w.editable)return false
  if(choice.kind==='register')return w.steward
  if(choice.kind==='reserve')return item?.canReserve===true
  if(choice.kind==='reassign')return item?.canReassign===true
  if(choice.kind==='finance')return item?.canStartFinance===true
  if(choice.kind==='replacement')return loan?.canStartFinance===true&&loan.history.some(e=>e.incidentId===choice.incident&&!e.financeStarted)
  if(!loan||choice.kind!=='movement')return false
  if(choice.action==='cancel')return loan.state==='reserved'
  if(!loan.custodian)return false
  return choice.action==='issue'?loan.state==='reserved'&&canIssue(loan):loan.outstanding>0
}

export function InventoryOverviewActions({api,term}: {api:InventoryApi;term:string}){
  const [search]=useSearchParams(),[entry,setEntry]=useState<{term:string;value:InventoryEntry}|null>(null)
  useEffect(()=>{
    let live=true,sequence=0
    const check=()=>{
      const current=++sequence
      void api.entry(term).then(value=>{if(live&&current===sequence)setEntry({term,value})})
        .catch(()=>{if(live&&current===sequence)setEntry(null)})
    }
    check()
    window.addEventListener('focus',check)
    const timer=setInterval(()=>{if(document.visibilityState!=='hidden')check()},30000)
    return()=>{live=false;clearInterval(timer);window.removeEventListener('focus',check)}
  },[api,term])
  const current=entry?.term===term?entry.value:null
  if(!current?.enabled)return null
  const query=search.has('term')?'?term='+term:''
  return <>
    <Link className="button button--secondary" to={'/inventory'+query}>Borrow inventory</Link>
    {current.checkout?<Link className="button button--secondary" to={'/inventory/'+current.checkout.id+query}>
      Check out {current.checkout.item} · {current.checkout.reference}</Link>:null}
    {current.dueReturn?<Link className="button button--secondary" to={'/inventory/'+current.dueReturn.id+query}>
      Return {current.dueReturn.item} · {current.dueReturn.reference}</Link>:null}
  </>
}

export function InventoryPage({api}:{api:InventoryApi}){
  const c=useRouteLoaderData('workspace')as WorkspaceContext,{inventoryLoanId}=useParams(),[search]=useSearchParams()
  if(!('memberId'in c))return <EmptyState title="Inventory unavailable" description="Check your current workspace access."/>
  return <InventoryBody key={c.termId+':'+c.memberId+':'+inventoryLoanId} api={api} term={c.termId}
    loanId={inventoryLoanId??null} termQuery={search.has('term')?'?term='+c.termId:''}/>
}

function InventoryBody({api,term,loanId,termQuery}:{api:InventoryApi;term:string;loanId:string|null;termQuery:string}){
  const [itemPage,changeItemPage]=useState(1),[loanPage,changeLoanPage]=useState(1)
  const [filter,setFilter]=useState(''),[query,setQuery]=useState('')
  const [workspace,setWorkspace]=useState<InventoryWorkspace|null>(null)
  const [checking,setChecking]=useState(true),[failed,setFailed]=useState(false)
  const [choice,setChoice]=useState<InventoryAction|null>(null)
  const [receipt,setReceipt]=useState<InventoryReceipt|null>(null)
  const generation=useRef(0),initialized=useRef(false),activeChoice=useRef<InventoryAction|null>(null)
  const confirmation=useRef<HTMLParagraphElement>(null)
  const editor=useRef<HTMLDivElement>(null),focusEditor=useRef(false)

  const load=useCallback(async()=>{
    const current=++generation.current
    setChecking(true);setFailed(false)
    try{
      const next=await api.read(term,loanId,itemPage,loanPage,query)
      if(generation.current!==current)return
      if(!next)setReceipt(null)
      const opened=activeChoice.current
      if(opened){
        const records=next?details(next,opened):null
        const losesScope=!next||('loan'in opened&&!records?.loan)||
          ('item'in opened&&!records?.item)||opened.kind==='register'&&!next.steward||
          (opened.kind==='replacement'||opened.kind==='movement'&&opened.action!=='cancel')&&!records?.loan?.custodian||
          opened.kind==='reassign'&&!records?.item?.canReassign||opened.kind==='finance'&&!records?.item?.canStartFinance
        if(losesScope){
          forgetRecordDrafts('loan'in opened?opened.loan:'item'in opened?opened.item:'register')
          setReceipt(null);setChoice(null);activeChoice.current=null
        }
      }
      setWorkspace(next)
      if(next&&!initialized.current){
        initialized.current=true
        const l=loanId?next.loans[0]:undefined
        if(l?.custodian&&(l.outstanding>0||l.state==='reserved'&&canIssue(l))){
          const opening:InventoryAction={kind:'movement',loan:l.id,action:l.state==='reserved'?'issue':'return'}
          activeChoice.current=opening
          setChoice(opening)
        }
      }
    }catch{if(generation.current===current)setFailed(true)}
    finally{if(generation.current===current)setChecking(false)}
  },[api,term,loanId,itemPage,loanPage,query])

  useEffect(()=>{
    const check=()=>{if(document.visibilityState!=='hidden')void load()}
    check();window.addEventListener('focus',check);document.addEventListener('visibilitychange',check)
    const timer=setInterval(check,30000)
    return()=>{generation.current++;clearInterval(timer);window.removeEventListener('focus',check);document.removeEventListener('visibilitychange',check)}
  },[load])
  useEffect(()=>{if(receipt)confirmation.current?.focus()},[receipt])
  useEffect(()=>{if(choice&&focusEditor.current){editor.current?.focus();focusEditor.current=false}},[choice])

  function choose(selected:InventoryAction){
    focusEditor.current=true
    activeChoice.current=selected
    setReceipt(null);setChoice(selected)
  }
  function close(){activeChoice.current=null;setChoice(null)}
  function saved(value:InventoryReceipt){close();setReceipt(value);void load()}

  const retained=workspace&&choice?details(workspace,choice):null
  const loansHref='/inventory'+termQuery
  const itemForLoan=loanId?workspace?.items[0]:undefined
  return <div className="inventory">
    <PageHeading title={loanId?'Inventory booking':'Borrow inventory'} description={workspace?.termLabel}/>
    {loanId?<Link className="button button--secondary" to={loansHref}>Back to inventory</Link>:null}
    {failed?<ErrorState title="Inventory unavailable" description="Check your connection and current access. Your entered details are kept."
      action={<button className="button" onClick={()=>void load()}>Check inventory again</button>}/>:null}
    {!workspace&&checking?<LoadingState title="Checking inventory availability"/>:null}
    {!workspace&&!checking&&!failed?<EmptyState title="Inventory is unavailable" description="Check the current term or ask the inventory service for help."
      action={<Link className="button button--secondary" to="/people">Find a permitted contact</Link>}/>:null}
    {workspace?<div hidden={failed}>
      {receipt?<p ref={confirmation} tabIndex={-1} role="status" className="inventory-result">
        {'loanId'in receipt?<>{loanId?'Saved':'Reserved'} · {receipt.reference}{!loanId?
          <> <Link className="button button--secondary" to={'/inventory/'+receipt.loanId+termQuery}>Open booking {receipt.reference}</Link></>:null}</>:
          'financeRequestId'in receipt?<>Private FIN draft created. <Link className="button button--secondary" to={'/finance/'+term+'/'+receipt.financeRequestId+termQuery}>Open FIN request</Link></>:
          'Inventory item saved.'}
      </p>:null}
      {checking&&workspace?<p role="status">Checking current stock and bookings…</p>:null}
      <div inert={checking}>
        {loanId&&workspace.loans[0]?<LoanSummary loan={workspace.loans[0]} item={itemForLoan} term={term}
          termQuery={termQuery} choose={choose} editing={!!choice} editable={workspace.editable}/>:null}
        {choice&&retained?<div ref={editor} tabIndex={-1}>
          <InventoryEditor key={JSON.stringify(choice)} choice={choice} api={api} term={term} workspace={workspace}
            item={retained.item} loan={retained.loan} checking={checking}
            allowed={canUse(workspace,choice,retained.loan,retained.item)} refresh={()=>void load()} saved={saved} close={close}/>
        </div>:null}
        {!loanId?<div className="inventory-sections">
          <Panel title="Item availability">
            <form className="inventory-search" onSubmit={event=>{
              event.preventDefault()
              changeItemPage(1)
              setQuery(filter.trim())
            }}>
              <TextField id="inventory-item-search" label="Search by item or pickup location" type="search"
                maxLength={160} value={filter} disabled={!!choice} onChange={event=>setFilter(event.target.value)}/>
              <button className="button button--secondary" disabled={!!choice}>Find items</button>
            </form>
            {workspace.steward&&!choice?<button className="button button--secondary" onClick={()=>choose({kind:'register'})}>Register an item</button>:null}
            {workspace.items.length?<ul className="inventory-list">{workspace.items.map(i=><li key={i.id}>
              <h3>{i.name}</h3><p><strong>{i.available} available</strong> · {i.kind==='returnable'?'Returnable equipment':'Consumable supplies'}</p>
              <p>{i.location} · {i.custodian?'Custodian '+i.custodian:'Custodian assignment needed'}</p>
              {!choice?<div className="auth-actions">
                {i.canReserve&&i.available>0?<button className="button" onClick={()=>choose({kind:'reserve',item:i.id})}>Reserve {i.name}</button>:null}
                {i.canReassign&&(i.needsCustodian||workspace.custodians.some(person=>person.id!==i.custodianId))?
                  <button className="button button--secondary" onClick={()=>choose({kind:'reassign',item:i.id})}>
                    {i.needsCustodian?'Assign replacement custodian':'Reassign custodian'} · {i.name}</button>:null}
                {i.canStartFinance?<button className="button button--secondary" onClick={()=>choose({kind:'finance',item:i.id})}>Request purchase · {i.name}</button>:null}
              </div>:null}
            </li>)}</ul>:<p>{query?'No items match this search.':'No items on this page. Ask the inventory service about available stock.'}</p>}
            {itemPage>1||workspace.moreItems?<div className="auth-actions">
              <button className="button button--secondary" disabled={!!choice||itemPage===1} onClick={()=>changeItemPage(v=>v-1)}>Previous items</button>
              <button className="button button--secondary" disabled={!!choice||!workspace.moreItems} onClick={()=>changeItemPage(v=>v+1)}>More items</button>
            </div>:null}
          </Panel>
          <Panel title={workspace.steward?'Inventory bookings in your care':'My inventory bookings'}>
            {workspace.loans.length?<ul className="inventory-list">{workspace.loans.map(l=><li key={l.id}>
              <h3><Link className="button button--secondary" to={'/inventory/'+l.id+termQuery}>{l.item} · {l.reference}</Link></h3>
              <p>{loanStates[l.state]} · {l.quantity} units{l.custodian?' · '+l.borrower:''}</p>
              <p>{l.kind==='returnable'?'Return by '+l.dueOn:'Pickup '+l.startsOn}</p>
            </li>)}</ul>:<p>Bookings you can access will appear here.</p>}
            {loanPage>1||workspace.moreLoans?<div className="auth-actions">
              <button className="button button--secondary" disabled={!!choice||loanPage===1} onClick={()=>changeLoanPage(v=>v-1)}>Previous bookings</button>
              <button className="button button--secondary" disabled={!!choice||!workspace.moreLoans} onClick={()=>changeLoanPage(v=>v+1)}>More bookings</button>
            </div>:null}
          </Panel>
        </div>:null}
      </div>
      <div className="auth-actions">
        <button className="button button--secondary" disabled={checking} onClick={()=>void load()}>Refresh inventory</button>
        <Link className="button button--secondary" to="/people">Find inventory help</Link>
      </div>
    </div>:null}
  </div>
}

function LoanSummary({loan:l,item,term,termQuery,choose,editing,editable}:{
  loan:Loan;item?:StockItem;term:string;termQuery:string;choose:(a:InventoryAction)=>void;editing:boolean;editable:boolean
}){
  return <Panel title={l.item+' · '+l.reference}>
    <p><strong>{loanStates[l.state]}</strong>{l.consumed?' · issued for consumption':''}</p>
    <p>{l.quantity} units · Pickup {l.startsOn}{l.kind==='returnable'?' · Return by '+l.dueOn:''} (Manila)</p>
    <p>{l.location} · {item?.custodian?'Custodian '+item.custodian:'Custodian assignment needed'}</p>
    {l.custodian?<p>Borrower {l.borrower}{!l.borrowerActive?' · workspace access ended':''}</p>:null}
    {l.state==='reserved'?<p>{l.custodian&&!canIssue(l)?'Check pickup date and current borrower access before issuing.':
      'Collect at pickup. The custodian records physical checkout.'}</p>:null}
    {l.kind==='returnable'&&l.state!=='reserved'&&l.state!=='cancelled'?<dl className="inventory-balance">
      <div><dt>Still out</dt><dd>{l.outstanding}</dd></div><div><dt>Returned</dt><dd>{l.returned}</dd></div>
      {l.damaged?<div><dt>Damaged</dt><dd>{l.damaged}</dd></div>:null}
      {l.lost?<div><dt>Lost</dt><dd>{l.lost}</dd></div>:null}
    </dl>:null}
    {editable&&!editing?<div className="auth-actions">
      {l.custodian&&l.state==='reserved'&&canIssue(l)?
        <button className="button" onClick={()=>choose({kind:'movement',loan:l.id,action:'issue'})}>Review checkout</button>:null}
      {l.state==='reserved'?<button className="button button--secondary" onClick={()=>choose({kind:'movement',loan:l.id,action:'cancel'})}>Review cancellation</button>:null}
      {l.custodian&&l.outstanding>0?<button className="button" onClick={()=>choose({kind:'movement',loan:l.id,action:'return'})}>Review return</button>:null}
    </div>:null}
    {editable&&!editing&&l.custodian&&l.outstanding>0?<details className="work-section"><summary>Report damage or loss</summary>
      <div className="auth-actions">
        <button className="button button--secondary" onClick={()=>choose({kind:'movement',loan:l.id,action:'damage'})}>Record damaged units</button>
        <button className="button button--secondary" onClick={()=>choose({kind:'movement',loan:l.id,action:'loss'})}>Record lost units</button>
      </div></details>:null}
    {l.relatedWork?<p>Related work <Link className="button button--secondary" to={'/'+(l.relatedWork.kind==='task'?'tasks':'deliverables')+'/'+l.relatedWork.id+termQuery}>{l.relatedWork.label}</Link></p>:null}
    <details className="work-section"><summary>Booking history</summary>
      <ol className="inventory-list">{l.history.map(h=><li key={h.version}>
        <p>{historyNames[h.action]} · {h.quantity} units{h.condition?' · '+conditions[h.condition]:''} · {formatted.format(new Date(h.at))}</p>
        {h.note?<p className="record-text">{h.note}</p>:null}
        {h.evidence?<p>Finalized evidence recorded</p>:null}
        {h.financeRequestId?<Link className="button button--secondary" to={'/finance/'+term+'/'+h.financeRequestId+termQuery}>Open private FIN follow-up</Link>:
          h.financeStarted?<p>FIN follow-up started</p>:null}
        {h.incidentId&&l.canStartFinance&&!h.financeStarted&&!editing?
          <button className="button button--secondary" onClick={()=>choose({kind:'replacement',loan:l.id,incident:h.incidentId!})}>Request replacement through FIN</button>:null}
      </li>)}</ol>
    </details>
  </Panel>
}
