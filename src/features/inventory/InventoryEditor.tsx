import {useEffect,useId,useState,type ComponentProps,type FormEvent} from 'react'
import {Link} from 'react-router'
import {Panel} from '../../components/Page'
import {TextField} from '../../components/TextField'
import {forgetRecordDrafts} from '../auth/draftScope'
import {useFinDecision} from '../finance/DecisionMemory'
import type {InventoryApi,InventoryCommand,InventoryEvidence,InventoryReceipt,InventoryWorkspace,Loan,Movement,StockItem} from './api'

export type InventoryAction=
  {kind:'register'}|
  {kind:'reserve'|'reassign'|'finance';item:string}|
  {kind:'movement';loan:string;action:Movement}|
  {kind:'replacement';loan:string;incident:string}

export const movementLabel:Record<Movement,string>={
  issue:'Confirm physical checkout',return:'Record return',damage:'Record damaged items',loss:'Record lost items',cancel:'Cancel reservation',
}
const label={
  reserve:'Reserve inventory',register:'Register item',reassign:'Assign custodian',
  finance:'Start FIN purchase request',replacement:'Start FIN replacement request',
}
const timestamp=new Intl.DateTimeFormat('en-PH',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Manila'})
const conditionValue=(v:string)=>v==='usable'||v==='worn'?v:null
const incident=(action:InventoryAction)=>action.kind==='movement'&&(action.action==='damage'||action.action==='loss')
const focusReview=(heading:HTMLHeadingElement|null)=>{heading?.focus()}

export function InventoryEditor({choice,api,term,workspace,item,loan,checking,allowed,close,refresh,saved}:{
  choice:InventoryAction;api:InventoryApi;term:string;workspace:InventoryWorkspace;item?:StockItem;loan?:Loan;
  checking:boolean;allowed:boolean;close:()=>void;refresh:()=>void;saved:(receipt:InventoryReceipt)=>void
}){
  const id=useId()
  const key='inventory:'+term+':'+('loan'in choice?choice.loan:'item'in choice?choice.item:'register')
  const recordVersion=(choice.kind==='movement'?loan?.version:item?.version)??0
  const [base,setBase]=useState(recordVersion),[localError,setLocalError]=useState('')
  const [review,setReview]=useState(false),[dirty,setDirty]=useState(false)
  const [evidence,setEvidence]=useState<{rows:InventoryEvidence[]|null;failed:boolean}>()
  const [evidenceRefresh,setEvidenceRefresh]=useState(0)
  const action=choice.kind==='movement'?choice.action:null
  const recordEvidence=incident(choice)
  const m=useFinDecision(api,key+':'+(action??choice.kind),{
    name:'',location:'',kind:'returnable',custodian:choice.kind==='register'?workspace.actorId:'',
    quantity:choice.kind==='reserve'?'1':action==='return'?String(loan?.outstanding??1):recordEvidence?'1':'',
    startsOn:'',dueOn:'',work:'',condition:'',note:'',evidence:'',
  })
  const fields=m.fields
  const stale=base!==recordVersion
  const title=action===null?label[choice.kind as keyof typeof label]:movementLabel[action]
  useEffect(()=>{
    if(!recordEvidence||!loan?.id)return
    let live=true
    void api.evidence(term,loan.id).then(rows=>{if(live)setEvidence({rows,failed:false})})
      .catch(()=>{if(live)setEvidence({rows:null,failed:true})})
    return()=>{live=false}
  },[api,loan?.id,term,recordEvidence,evidenceRefresh])

  function field(name:string,value:string){
    m.change({...fields,[name]:value});setDirty(true);setLocalError('')
  }
  function discard(){
    if(dirty&&!window.confirm('Discard these inventory entries?'))return
    forgetRecordDrafts('loan'in choice?choice.loan:'item'in choice?choice.item:'register')
    close()
  }
  async function send(command?:InventoryCommand){
    const result=await m.run(command)
    if(result){setDirty(false);saved(result)}else refresh()
  }
  function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault()
    if(!allowed||checking||stale||m.locked)return
    const quantity=Number(fields.quantity),condition=conditionValue(fields.condition),note=fields.note.trim()||null
    if(choice.kind==='register'&&condition&&(fields.kind==='returnable'||fields.kind==='consumable')){
      void send({kind:'register',term,name:fields.name,location:fields.location,itemKind:fields.kind,quantity,condition,custodian:fields.custodian})
    }else if(choice.kind==='reserve'&&item){
      const dueOn=item.kind==='consumable'?fields.startsOn:fields.dueOn
      if(!Number.isInteger(quantity)||quantity<1||quantity>item.available||dueOn<fields.startsOn){
        setLocalError('Check the available quantity and the pickup and return dates.');return
      }
      if(!review){setReview(true);return}
      void send({kind:'reserve',term,item:item.id,version:base,quantity,startsOn:fields.startsOn,dueOn,work:fields.work||null})
    }else if(choice.kind==='movement'&&loan){
      if((choice.action==='return'||recordEvidence)&&(!Number.isInteger(quantity)||quantity<1||quantity>loan.outstanding)){
        setLocalError('Enter a quantity from the units still out.');return
      }
      if(recordEvidence&&!evidence?.rows?.some(file=>file.id===fields.evidence)){
        setLocalError('Choose finalized evidence you can access.');return
      }
      void send({kind:'movement',term,loan:loan.id,version:base,action:choice.action,quantity:
        choice.action==='issue'||choice.action==='cancel'?loan.quantity:quantity,
      condition,note,evidence:fields.evidence||null})
    }else if(choice.kind==='reassign'&&item&&note){
      void send({kind:'reassign',term,item:item.id,version:base,custodian:fields.custodian,note})
    }else if((choice.kind==='finance'||choice.kind==='replacement')&&item){
      void send({kind:'finance',term,item:item.id,version:base,incident:choice.kind==='replacement'?choice.incident:null})
    }else setLocalError('Check the required inventory fields.')
  }
  const input=(name:string,nameLabel:string,options:Omit<ComponentProps<typeof TextField>,'id'|'label'|'value'|'onChange'>={})=>
    <TextField id={id+name} label={nameLabel} value={fields[name]} onChange={e=>field(name,e.target.value)} {...options}/>
  const conditionFields=<fieldset className="inventory-condition"><legend>Physical condition (required)</legend>
    <label><input name={id+'condition'} type="radio" value="usable" checked={fields.condition==='usable'}
      onChange={()=>field('condition','usable')} required/>Usable</label>
    <label><input name={id+'condition'} type="radio" value="worn" checked={fields.condition==='worn'}
      onChange={()=>field('condition','worn')} required/>Worn · still usable</label>
  </fieldset>
  const isFinance=choice.kind==='finance'||choice.kind==='replacement'
  const itemName=item?.name??loan?.item
  return <Panel title={title} className="inventory-editor">
    {itemName?<p><strong>{itemName}</strong>{loan?' · '+loan.reference:''}{item?' · '+item.location:''}</p>:null}
    {localError||m.error?<p role="alert">{localError||m.error}</p>:null}
    {m.pending?<div data-pending-command="true">
      <p>Checking the result. Retry the same entries to recover this action.</p>
      <button className="button" disabled={m.busy} onClick={()=>void send()}>Check whether inventory saved</button>
    </div>:null}
    {!allowed&&!m.pending?<p role="status">The current stock, booking or your access changed. Check the latest details.</p>:null}
    {allowed&&stale&&!m.pending?<div role="alert"><p>This record changed. Review the latest quantities before sending.</p>
      <button className="button button--secondary" disabled={checking} onClick={()=>{setBase(recordVersion);setReview(false);setLocalError('');m.change(fields)}}>Keep entries and review latest</button>
    </div>:null}
    <form onSubmit={submit} data-unsaved-changes={dirty} data-pending-command={m.locked}>
      <fieldset disabled={checking||m.locked||stale||!allowed}>
        {choice.kind==='register'?<>
          {input('name','Item name',{required:true,maxLength:160})}{input('location','Pickup location',{required:true,maxLength:160})}
          <div className="form-field"><label htmlFor={id+'kind'}>Item type</label><select id={id+'kind'} value={fields.kind} onChange={e=>field('kind',e.target.value)}>
            <option value="returnable">Returnable equipment</option><option value="consumable">Consumable supplies</option>
          </select></div>
          {input('quantity','Counted opening quantity',{type:'number',required:true,min:0,max:100000})}{conditionFields}
        </>:null}
        {choice.kind==='register'||choice.kind==='reassign'?<div className="form-field"><label htmlFor={id+'custodian'}>Current eligible custodian</label>
          <select id={id+'custodian'} required value={fields.custodian} onChange={e=>field('custodian',e.target.value)}>
            <option value="">Choose a custodian</option>{workspace.custodians.filter(person=>choice.kind==='register'||person.id!==item?.custodianId)
              .map(person=><option key={person.id} value={person.id}>{person.name}</option>)}
          </select>
        </div>:null}
        {choice.kind==='reserve'&&item?<><p role="status">{item.available} available · {item.custodian??'Custodian assignment needed'}</p>
          {review?<div>
            <h3 tabIndex={-1} ref={focusReview}>Review your reservation</h3>
            <p>{fields.quantity} × {item.name} · Pickup {fields.startsOn}
              {item.kind==='returnable'?' · Return by '+fields.dueOn:' · Consumable'}</p>
            {fields.work?<p>{workspace.work.find(w=>w.id===fields.work)?.label??'Previously selected work'}</p>:null}
            <p>Stock is set aside when you send this reservation. Collect it from {item.custodian}.</p>
            <button type="button" className="button button--secondary" onClick={()=>setReview(false)}>Back to change reservation</button>
          </div>:<>
            {input('quantity','Quantity',{required:true,type:'number',min:1,max:Math.max(1,item.available)})}
            {input('startsOn','Pickup date (Manila)',{type:'date',required:true})}
            {item.kind==='returnable'?input('dueOn','Return by (Manila)',{type:'date',required:true,min:fields.startsOn}):
              <p>Consumed stock is recorded at pickup.</p>}
            {workspace.work.length?<div className="form-field"><label htmlFor={id+'work'}>Related work (optional)</label>
              <select id={id+'work'} value={fields.work} onChange={e=>field('work',e.target.value)}>
              <option value="">Choose related work</option>{workspace.work.map(w=><option key={w.id} value={w.id}>{w.label}</option>)}</select></div>:null}
          </>}
        </>:null}
        {action==='issue'&&loan?<><p>Confirm only after handing {loan.quantity} {loan.quantity===1?'unit':'units'} to {loan.borrower} at {loan.location}.</p>{conditionFields}</>:null}
        {action==='return'&&loan?<><p>{loan.outstanding} still out. Check the quantity and condition before restoring stock.</p>
          {input('quantity','Units returned',{type:'number',required:true,min:1,max:loan.outstanding})}{conditionFields}</>:null}
        {action==='cancel'&&loan?<p>Release all {loan.quantity} reserved units. The reference and reason stay in the booking history.</p>:null}
        {recordEvidence&&loan?<><p>{loan.outstanding} still out. Damaged and lost units stay out of available stock.</p>
          {input('quantity',action==='loss'?'Units lost':'Units damaged',{type:'number',required:true,min:1,max:loan.outstanding})}
          <div className="form-field"><label htmlFor={id+'evidence'}>Finalized evidence (required)</label>
            <select id={id+'evidence'} required value={fields.evidence} onChange={e=>field('evidence',e.target.value)}>
            <option value="">Select a document</option>{evidence?.rows?.map(e=>
              <option key={e.id} value={e.id}>{e.work} · {e.files.join(', ')} · {timestamp.format(new Date(e.at))}</option>)}
          </select></div>
          {!evidence?<p role="status">Checking finalized evidence…</p>:null}
          {evidence?.failed?<p role="alert">Evidence could not be checked.</p>:null}
          {evidence?.rows?.length===0?<p>Finalize the incident record in permitted work, then refresh the evidence choices.</p>:null}
          <div className="auth-actions">
            <Link className="button button--secondary" target="_blank" rel="noopener"
              to={loan.relatedWork?'/'+(loan.relatedWork.kind==='task'?'tasks':'deliverables')+'/'+loan.relatedWork.id:'/search'}>
              {loan.relatedWork?'Open related work in a new tab':'Find work for evidence in a new tab'}</Link>
            <button type="button" className="button button--secondary" onClick={()=>setEvidenceRefresh(n=>n+1)}>Refresh evidence</button>
          </div>
        </>:null}
        {recordEvidence||action==='cancel'||choice.kind==='reassign'?input('note',
          recordEvidence?'Incident details':action==='cancel'?'Why are you cancelling?':'Custody change reason',
          {required:true,maxLength:2000}):null}
        {isFinance?<p>Open a private FIN draft. Enter the costs there for independent review before committing money.</p>:null}
        <button className="button" type="submit">{choice.kind==='reserve'?(review?'Send reservation':'Review reservation'):
          action==='cancel'?'Confirm cancellation':title}</button>
      </fieldset>
      <button className="button button--secondary" type="button" disabled={m.locked} onClick={discard}>Close action</button>
    </form>
  </Panel>
}
