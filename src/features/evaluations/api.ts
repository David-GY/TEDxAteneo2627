import {mapCommandError,type CommandResult} from '../../lib/commands'
import type {createSupabaseClient} from '../../lib/supabase'

export type EvaluationPrompt={key:string;label:string;required:boolean;maxLength:number}
export type EvaluationAnswers=Record<string,string>
export type EvaluationCase={
  id:string;version:number;round:string;purpose:string;subject:string|null
  asSubject:boolean;asAuthor:boolean;asReviewer:boolean;asCustodian:boolean
  authorState:'submitted'|'withdrawn'|null;subjectState:'released'|'awaiting_release'|null
  closesAt:string;releaseAfter:string;retention:{category:'prism';owner:string;basis:string;days:number;action:'archive_review'|'review_disposal'}
  reviewRequired:true;releasePolicy:'independent_summary'
}
export type EvaluationWorkspace={enabled:boolean;setup:string|null;anonymity:string;hasMore:boolean;cases:EvaluationCase[]}
export type AuthorRevision={revision:number;state:'submitted'|'withdrawn';answers:EvaluationAnswers|null;at:string}
export type EvaluationSubmission=AuthorRevision&{id:string;author:string;own:boolean;history:AuthorRevision[]|null}
export type ReviewerNote={id:string;body:string;author:string;at:string}
export type ReleaseDraft={id:string;subjectId:string;summary:string;version:number;own:boolean;current:boolean;published:boolean}
export type EvaluationRecord={
  caseId:string;version:number;round:string;purpose:string;subjectId:string;subject:string
  template:EvaluationPrompt[];closesAt:string;appealUntil:string;releaseAfter:string
  retention:EvaluationCase['retention']
  reviewer:boolean;canPrepare:boolean;canRelease:boolean
  submissions:EvaluationSubmission[];notes:ReviewerNote[];releaseDrafts:ReleaseDraft[]
}
export type EvaluationSummary={
  caseId:string;round:string;purpose:string;state:'released'|'awaiting_release'|'awaiting_updated_summary'
  summary:string|null;releasedAt:string|null
}
export type EvaluationAssignment={
  id:string;version:number;memberId:string;kind:'author'|'reviewer'|'releaser'
  active:boolean;startsAt:string;endsAt:string;conflicted:boolean
}
export type EvaluationExportGrant={id:string;memberId:string;version:number;expiresAt:string;revoked:boolean}
export type EvaluationSetup={
  people:{id:string;name:string}[]
  authorities:{id:string;memberId:string;unitId:string;unit:string}[]
  rounds:{id:string;label:string;purpose:string;unitId:string;opensAt:string;closesAt:string;releaseAfter:string;appealUntil:string
    template:EvaluationPrompt[];retention:EvaluationCase['retention']
    cases:{id:string;version:number;subjectId:string;assignments:EvaluationAssignment[];exports:EvaluationExportGrant[]}[]}[]
}
export type EvaluationReceipt={id:string;version:number}
export type EvaluationReport={state:'not_ready'|'suppressed'|'ready'|'published';cohort:'5 or more'|null;at:string|null}
export type EvaluationOwnExport={id:string;version:number;expiresAt:string}
export type EvaluationCommand={term:string}&(
  {kind:'report'}|
  {kind:'round';unit:string;authority:string;label:string;purpose:string;template:EvaluationPrompt[];
    opensAt:string;closesAt:string;releaseAfter:string;appealUntil:string}|
  {kind:'case';round:string;subject:string}|
  {kind:'assign';caseId:string;version:number;member:string;role:EvaluationAssignment['kind'];startsAt:string;endsAt:string;authority:string|null}|
  {kind:'endAssignment';assignment:string;version:number;conflicted:boolean}|
  {kind:'submit';caseId:string;revision:number;answers:EvaluationAnswers|null;withdraw:boolean}|
  {kind:'note';caseId:string;version:number;body:string}|
  {kind:'prepareRelease';caseId:string;version:number;subject:string;summary:string}|
  {kind:'publishRelease';draft:string;version:number;subject:string}|
  {kind:'grantExport';caseId:string;version:number;member:string;expiresAt:string;purposeReference:string}|
  {kind:'revokeExport';grant:string;version:number})

const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v)
const text=(v:unknown):v is string=>typeof v==='string'&&v.trim().length>0
const int=(v:unknown,min=1,max=2147483647):v is number=>typeof v==='number'&&Number.isSafeInteger(v)&&v>=min&&v<=max
const optionalText=(v:unknown)=>v===null||text(v)
const flags=(...values:unknown[])=>values.every(v=>typeof v==='boolean')
const time=(v:unknown):v is string=>typeof v==='string'&&/(Z|[+-]\d{2}:\d{2})$/i.test(v)&&Number.isFinite(Date.parse(v))
const prompts=(v:EvaluationPrompt[])=>Array.isArray(v)&&v.length>0&&v.length<=12&&new Set(v.map(f=>f?.key)).size===v.length
  &&v.every(p=>p&&/^[a-z][a-z0-9_]{0,39}$/.test(p.key)&&text(p.label)&&typeof p.required==='boolean'&&int(p.maxLength,1,4000))
const retention=(r:EvaluationCase['retention'])=>r&&r.category==='prism'&&text(r.owner)&&text(r.basis)&&int(r.days,0,365000)
  &&['archive_review','review_disposal'].includes(r.action)
const revision=(v:AuthorRevision)=>v&&int(v.revision)&&['submitted','withdrawn'].includes(v.state)&&time(v.at)
  &&(v.state==='withdrawn'?v.answers===null:v.answers&&typeof v.answers==='object'&&!Array.isArray(v.answers)
    &&Object.entries(v.answers).every(([key,value])=>/^[a-z][a-z0-9_]{0,39}$/.test(key)&&typeof value==='string'))
const record=(r:EvaluationRecord|null,caseId?:string):r is EvaluationRecord=>!!r&&uuid(r.caseId)&&(!caseId||r.caseId===caseId)
  &&int(r.version)&&text(r.round)&&text(r.purpose)&&uuid(r.subjectId)&&text(r.subject)&&prompts(r.template)&&retention(r.retention)
  &&[r.closesAt,r.appealUntil,r.releaseAfter].every(time)&&flags(r.reviewer,r.canPrepare,r.canRelease)
  &&Array.isArray(r.submissions)&&r.submissions.every(s=>revision(s)&&uuid(s.id)&&text(s.author)&&flags(s.own)
    &&(s.history===null||s.own&&Array.isArray(s.history)&&s.history.every(revision)))
  &&Array.isArray(r.notes)&&r.notes.every(n=>n&&uuid(n.id)&&text(n.body)&&text(n.author)&&time(n.at))
  &&Array.isArray(r.releaseDrafts)&&r.releaseDrafts.every(d=>d&&uuid(d.id)&&d.subjectId===r.subjectId&&text(d.summary)
    &&int(d.version)&&flags(d.own,d.current,d.published))
  &&(r.reviewer||r.notes.length===0&&r.releaseDrafts.length===0&&r.submissions.every(s=>s.own))
const sanitizeRecord=(r:EvaluationRecord):EvaluationRecord=>({
  caseId:r.caseId,version:r.version,round:r.round,purpose:r.purpose,subjectId:r.subjectId,subject:r.subject,
  template:r.template.map(({key,label,required,maxLength})=>({key,label,required,maxLength})),
  retention:{category:'prism',owner:r.retention.owner,basis:r.retention.basis,days:r.retention.days,action:r.retention.action},
  closesAt:r.closesAt,appealUntil:r.appealUntil,releaseAfter:r.releaseAfter,
  reviewer:r.reviewer,canPrepare:r.canPrepare,canRelease:r.canRelease,
  submissions:r.submissions.map(({id,author,own,revision,state,answers,at,history})=>({
    id,author,own,revision,state,answers,at,history:history?.map(({revision,state,answers,at})=>({revision,state,answers,at}))??null,
  })),
  notes:r.notes.map(({id,body,author,at})=>({id,body,author,at})),
  releaseDrafts:r.releaseDrafts.map(({id,subjectId,summary,version,own,current,published})=>({id,subjectId,summary,version,own,current,published})),
})
const errorMessages:Record<string,string>={
  command_evaluation_report_frozen:'This term report is frozen. It cannot be republished with a narrower or changed cohort.',
  command_evaluation_report_suppressed:'The report needs closed collection and at least five distinct subjects with released summaries. No smaller count is disclosed.',
  command_evaluation_policy_unavailable:'PRISM needs its approved custodian, basis and published retention policy before this action is available.',
  command_evaluation_template_invalid:'Check the named questions and their text limits.',
  command_evaluation_assignment_conflict:'This person cannot take that role in this case. Review subject, author and conflict assignments.',
  command_evaluation_submission_closed:'Check the round dates and your current assignment before submitting.',
  command_evaluation_release_stale:'Feedback or assignments changed. Review the current material and prepare a new summary.',
  command_evaluation_release_not_ready:'Release requires the approved time and current submitted feedback.',
  command_evaluation_feedback_required:'A summary needs current submitted feedback.',
}

export function createEvaluationsApi(ready:ReturnType<typeof createSupabaseClient>){
  async function client(){
    const value=await ready
    if(!value)throw Error('PRISM connection unavailable')
    return value
  }
  return {
    async help(term:string):Promise<{complaintsUrl:string}|null>{
      const {data,error}=await(await client()).rpc('read_evaluation_help',{p_term_id:term})
      if(!error&&data===null)return null
      const h=data as {complaintsUrl:string}|null
      if(error||!h||typeof h.complaintsUrl!=='string')throw Error('Approved process unavailable')
      const url=new URL(h.complaintsUrl)
      if(url.protocol!=='https:'||url.username||url.password)throw Error('Approved process unavailable')
      return {complaintsUrl:url.href}
    },
    async exports(term:string,caseId:string):Promise<EvaluationOwnExport[]>{
      const {data,error}=await(await client()).rpc('read_evaluation_exports',{p_term_id:term,p_case_id:caseId})
      const list=data as EvaluationOwnExport[]|null
      if(error||!Array.isArray(list)||!list.every(g=>g&&uuid(g.id)&&int(g.version)&&time(g.expiresAt)))throw Error('Export approval unavailable')
      return list.map(({id,version,expiresAt})=>({id,version,expiresAt}))
    },
    async report(term:string):Promise<EvaluationReport>{
      const {data,error}=await(await client()).rpc('read_evaluation_report',{p_term_id:term})
      const r=data as EvaluationReport|null
      if(error||!r||!['not_ready','suppressed','ready','published'].includes(r.state)
        ||(r.state==='published'?r.cohort!=='5 or more'||!time(r.at):r.cohort!==null||r.at!==null))throw Error('Cohort report unavailable')
      return {state:r.state,cohort:r.cohort,at:r.at}
    },
    async workspace(term:string,page=1):Promise<EvaluationWorkspace>{
      const {data,error}=await(await client()).rpc('read_evaluation_workspace',{p_term_id:term,p_page:page})
      const w=data as EvaluationWorkspace|null
      if(error||!w||!flags(w.enabled,w.hasMore)||!optionalText(w.setup)||!text(w.anonymity)
        ||!Array.isArray(w.cases)||w.cases.length>30||!w.cases.every(c=>c&&uuid(c.id)&&int(c.version)&&text(c.round)&&text(c.purpose)
          &&optionalText(c.subject)&&flags(c.asSubject,c.asAuthor,c.asReviewer,c.asCustodian)
          &&(c.authorState===null||['submitted','withdrawn'].includes(c.authorState))
          &&(c.subjectState===null||['released','awaiting_release'].includes(c.subjectState))&&time(c.closesAt)&&time(c.releaseAfter)
          &&retention(c.retention)&&c.reviewRequired===true&&c.releasePolicy==='independent_summary')
        ||!w.enabled&&(w.cases.length!==0||!w.setup))throw Error('PRISM status could not be checked')
      return {enabled:w.enabled,setup:w.setup,anonymity:w.anonymity,hasMore:w.hasMore,cases:w.cases.map(c=>({
        id:c.id,version:c.version,round:c.round,purpose:c.purpose,subject:c.subject,
        asSubject:c.asSubject,asAuthor:c.asAuthor,asReviewer:c.asReviewer,asCustodian:c.asCustodian,
        authorState:c.authorState,subjectState:c.subjectState,closesAt:c.closesAt,releaseAfter:c.releaseAfter,
        retention:{category:'prism',owner:c.retention.owner,basis:c.retention.basis,days:c.retention.days,action:c.retention.action},
        reviewRequired:true,releasePolicy:'independent_summary',
      }))}
    },
    async setup(term:string):Promise<EvaluationSetup>{
      const {data,error}=await(await client()).rpc('read_evaluation_setup',{p_term_id:term})
      const s=data as EvaluationSetup|null
      if(error||!s||!Array.isArray(s.people)||!s.people.every(p=>p&&uuid(p.id)&&text(p.name))
        ||!Array.isArray(s.authorities)||!s.authorities.every(a=>a&&uuid(a.id)&&uuid(a.memberId)&&uuid(a.unitId)&&text(a.unit))
        ||!Array.isArray(s.rounds)||!s.rounds.every(r=>r&&uuid(r.id)&&uuid(r.unitId)&&text(r.label)&&text(r.purpose)
          &&[r.opensAt,r.closesAt,r.releaseAfter,r.appealUntil].every(time)&&prompts(r.template)&&retention(r.retention)
          &&Array.isArray(r.cases)&&r.cases.every(c=>c&&uuid(c.id)&&uuid(c.subjectId)&&int(c.version)
            &&Array.isArray(c.assignments)&&c.assignments.every(a=>a&&uuid(a.id)&&uuid(a.memberId)&&int(a.version)
              &&['author','reviewer','releaser'].includes(a.kind)&&flags(a.active,a.conflicted)&&time(a.startsAt)&&time(a.endsAt))
            &&Array.isArray(c.exports)&&c.exports.every(g=>g&&uuid(g.id)&&uuid(g.memberId)&&int(g.version)&&time(g.expiresAt)&&flags(g.revoked)))))
        throw Error('PRISM assignment setup could not be checked')
      return s
    },
    async record(term:string,caseId:string):Promise<EvaluationRecord|null>{
      const {data,error}=await(await client()).rpc('read_evaluation_record',{p_term_id:term,p_case_id:caseId})
      if(!error&&data===null)return null
      const r=data as EvaluationRecord|null
      if(error||!record(r,caseId))throw Error('Current feedback access could not be checked')
      return sanitizeRecord(r)
    },
    async summary(term:string,caseId:string):Promise<EvaluationSummary|null>{
      const {data,error}=await(await client()).rpc('read_evaluation_summary',{p_term_id:term,p_case_id:caseId})
      if(!error&&data===null)return null
      const r=data as EvaluationSummary|null
      if(error||!r||r.caseId!==caseId||!text(r.round)||!text(r.purpose)||!['released','awaiting_release','awaiting_updated_summary'].includes(r.state)
        ||(r.state==='released'?!text(r.summary)||!time(r.releasedAt):r.summary!==null||r.releasedAt!==null))
        throw Error('Released summary could not be checked')
      return {caseId:r.caseId,round:r.round,purpose:r.purpose,state:r.state,summary:r.summary,releasedAt:r.releasedAt}
    },
    async exportRecord(term:string,grant:string):Promise<EvaluationRecord|null>{
      const {data,error}=await(await client()).rpc('export_evaluation_record',{p_term_id:term,p_grant_id:grant})
      if(!error&&data===null)return null
      const r=data as EvaluationRecord|null
      if(error||!record(r))throw Error('The current export grant could not be checked')
      return sanitizeRecord(r)
    },
    async run(q:EvaluationCommand,key:string):Promise<CommandResult<EvaluationReceipt>>{
      try{
        const c=await client(),base={p_term_id:q.term,p_key:key}
        const response=q.kind==='report'?await c.rpc('publish_evaluation_report',base):q.kind==='round'?await c.rpc('create_feedback_round',{...base,p_unit_id:q.unit,p_authority_id:q.authority,
          p_label:q.label,p_purpose:q.purpose,p_template:q.template,p_opens_at:q.opensAt,p_closes_at:q.closesAt,
          p_release_after:q.releaseAfter,p_appeal_until:q.appealUntil}):
          q.kind==='case'?await c.rpc('create_evaluation_case',{...base,p_round_id:q.round,p_subject_id:q.subject}):
          q.kind==='assign'?await c.rpc('assign_evaluation_participant',{...base,p_case_id:q.caseId,p_expected_version:q.version,
            p_member_id:q.member,p_kind:q.role,p_starts_at:q.startsAt,p_ends_at:q.endsAt,p_authority_id:q.authority}):
          q.kind==='endAssignment'?await c.rpc('end_evaluation_assignment',{...base,p_assignment_id:q.assignment,p_expected_version:q.version,p_conflicted:q.conflicted}):
          q.kind==='submit'?await c.rpc('submit_evaluation',{...base,p_case_id:q.caseId,p_expected_revision:q.revision,
            p_action:q.withdraw?'withdraw':'submit',p_answers:q.answers}):
          q.kind==='note'?await c.rpc('append_evaluation_note',{...base,p_case_id:q.caseId,p_expected_version:q.version,p_body:q.body}):
          q.kind==='prepareRelease'?await c.rpc('prepare_evaluation_release',{...base,p_case_id:q.caseId,p_expected_version:q.version,p_subject_id:q.subject,p_summary:q.summary}):
          q.kind==='publishRelease'?await c.rpc('publish_evaluation_release',{...base,p_draft_id:q.draft,p_expected_version:q.version,p_subject_id:q.subject}):
          q.kind==='grantExport'?await c.rpc('grant_evaluation_export',{...base,p_case_id:q.caseId,p_expected_version:q.version,p_member_id:q.member,
            p_expires_at:q.expiresAt,p_purpose_reference:q.purposeReference}):
          await c.rpc('revoke_evaluation_export',{...base,p_grant_id:q.grant})
        if(response.error){
          const mapped=mapCommandError(response.error),message=errorMessages[response.error.message]
          return {ok:false,error:typeof message==='string'?{...mapped,message}:mapped}
        }
        const r=response.data as EvaluationReceipt|null
        const expected=q.kind==='round'||q.kind==='case'||q.kind==='report'?1:q.kind==='submit'?q.revision+1:
          q.kind==='assign'?null:q.kind==='endAssignment'||q.kind==='note'?q.version+1:q.version
        if(!r||!uuid(r.id)||!int(r.version)||expected!==null&&r.version!==expected||
          q.kind==='endAssignment'&&r.id!==q.assignment||q.kind==='revokeExport'&&r.id!==q.grant)throw Error()
        return {ok:true,value:{id:r.id,version:r.version}}
      }catch{return {ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}}
    },
  }
}
export type EvaluationsApi=ReturnType<typeof createEvaluationsApi>
