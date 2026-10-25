# Restricted finance payloads (P24)

Migration032 adds `finance_cases`, `finance_revisions` and `finance_lines`. All are forced-RLS, append-only and denied direct access to public/anon/authenticated/service_role. No finance joins were added to ordinary requests, search, counts, Overview or department inboxes. Existing independently authorized triage envelope metadata remains governed by P23; it confers no typed payload or evidence access.

## Submission contract

`submit_finance_request(p_work_item_id uuid, p_values jsonb, p_requested_on date, p_title text, p_finance_payload jsonb, p_expected_version integer, p_request_id uuid, p_revision boolean default false)`

The current core requester owns the existing FIN/restricted draft. Identity, route, form validation, term, current version and request lifecycle come from P21/P22; the command reuses `app_private.submit_request_revision` in the same transaction. `p_revision=true` submits an explicit revision draft. The existing `requested_centavos` form adapter, when present, receives the validated typed line total; callers cannot supply another amount. `p_values` contains configured envelope/file-selection values only, never finance lines or approval fields.

`p_request_id` is an actor/command-scoped idempotency UUID. Identical complete payload/key returns the original receipt after current ownership/admission checks. Changed payload/key is `22023`; stale version is `40001`; denied current scope is `42501`; wrong type/lifecycle/untyped later revision is `55000`. No optimistic success is implied. Keep the identical input and key to recover an uncertain result. The receipt extends P21 with `financeRevisionId` and `requestRevisionId` and contains no sensitive payload or money.

The closed finance object is:

```ts
{
  schemaVersion: 1,
  currency: 'PHP',
  kind: 'cost' | 'budget' | 'expense' | 'reimbursement' | 'fundraising' | 'sales',
  purpose: string,                 // nonblank, <=2000 characters
  fundSource: string,              // nonblank, <=500
  beneficiaryMemberId: string,     // current active core member in the same term
  relatedDeliverableId?: string | null, // same-term, unarchived, independently readable
  plannedOn?: string | null,       // date-only YYYY-MM-DD, years 0001..9999
  termsRisks: string,              // nonblank, <=4000
  requestedTotalCentavos: string,
  lines: [{                       // 1..100, <=100000 bytes for the entire input
    description: string,          // nonblank, <=500
    quantity: string,
    unitAmountCentavos: string,
    totalCentavos: string
  }],
  // Required only for fundraising/sales; forbidden for other kinds:
  pricing?: {
    unitPriceCentavos: string,
    forecastQuantity: string,
    forecastRevenueCentavos: string
  }
}
```

Unknown keys, numeric money JSON values, negative amounts, exponents, leading zero integers, wrong currency, malformed quantities/dates and inconsistent declared totals fail. Neither beneficiary selection nor a related deliverable grants access or authority. This slice intentionally supports member beneficiaries only; external beneficiaries need an explicit future privacy/design decision.

## Exact money and quantity policy

All monetary inputs/outputs are canonical decimal integer strings in **centavos**, range `0..9007199254740991`. The explicit upper bound also keeps the underlying generated bigint table types within JavaScript's safe range; those tables are not client-readable. Never widen the bound without changing serialization and tests. No PostgreSQL bigint beyond this bound is coerced to a JavaScript number.

Quantity is a canonical decimal string with up to three fractional digits, maximum `1000000`. Cost lines require quantity `>=0.001`; forecast quantity may be zero. The database stores exact integer thousandths as `quantity_milli` / `forecast_quantity_milli`, the equivalent of the specification's quantity_numeric. Each nonnegative product rounds half up: `floor((quantity_milli * unit_centavos + 500) / 1000)`. Requested total sums the already rounded cost lines. Forecast revenue applies the same rule to price and forecast quantity. Products and sums use PostgreSQL numeric / TypeScript BigInt before range checks. Decimal PHP text is parsed without `Number`, `parseFloat` or binary floating money. Zero cost, zero forecast and negative derived forecast margin are valid plans.

`src/features/finance/money.ts` exports `parsePhp`, `lineTotal`, `sumCentavos` and `forecastRevenue` for P25's presentation. PostgreSQL repeats all trusted validation.

## Immutable revision and evidence binding

The command freezes typed columns/lines beside the exact submitted request revision. The selected P12 request manifest and its SHA-256 are copied from that revision, never supplied as finance hashes or mutable external links. P21's exact finalized, same-request file selection remains authoritative; P12 reauthorizes every byte download. No file access is widened. No evidence policy is invented: mandatory school/receipt evidence remains an institutional configuration/acceptance gate.

`payload_hash` is lowercase SHA-256 over PostgreSQL UTF-8 jsonb text of `{hashVersion:'sha256-jsonb-v1', requestRevisionId, manifestHash, payload: normalizedFinanceObject}`. Normalization replaces quantities with integer thousandths and normalizes line/price totals to strings. P26 must verify/use the server-owned exact finance revision/hash, not a caller claim or a browser's serialization. The payload hash identifies a plan; it is not an approval or signature.

Once a case has a typed finance snapshot, a deferred constraint trigger requires every later request revision to have its own typed snapshot at commit. An old generic FIN envelope without a finance case remains an unbound, paused P21/P22 envelope; it cannot become financial authorization. To add typed data, the requester begins an explicit revision and uses this atomic command. Generic revisions cannot bypass a typed case's requirement. New snapshots never overwrite earlier payloads/files/hashes.

## Audited read boundary and remaining gates

`read_finance_revision(p_term_id uuid, p_work_item_id uuid, p_revision integer default null)` returns the requested or current typed revision only to the current admitted core requester with current work access. Unrelated readers receive null; invalid admission is denied. Success appends a redacted access audit with no amounts, descriptions, fund, beneficiary or evidence contents. The response includes typed header/lines, string money, optional forecast/margin, exact manifest/files and server hashes. No storage paths or signed URLs are returned. Use P12's existing download command for bytes.

P24 installs **no FIN participant/reviewer authority**. Service heads, associates, beneficiary status and labels do not grant typed access. P26 owns independently authorized FIN participants/reviews. FIN/MCD hooks stay fail-closed. Forecasts create no actual revenue, reservation, authorization or payment; P27 owns documented actuals/ledger work. P25 owns forms/detail/desk UI and has not been implemented.

Local isolated P24_A1–A3 evidence is in `docs/build/steps/P24.md` and `docs/build/evidence/P24-domain.json`. Real Supabase17/Auth/Storage/JWT access/revocation, independent concurrent sessions, deployed redaction, approved authority/privacy/retention/evidence policy and human acceptance remain unverified; all earlier gates persist.

## P25 intake, private history and shared summaries

Migration033 adds presentation reads only, with no new table or review authority. `read_request` retains its P24 signature and scope and adds `governedKind` for server-derived route selection. `read_finance_intake(term,request,revision?)` returns only an owned FIN request envelope, P24 audited typed revision, current form/file/member choices when editable, up to100 independently readable current deliverables, and current process note. A revoked/unrelated account receives no case; current request/form/file authority is still checked. `list_finance_cases(term,page=1)` uses the same current owner/core access predicate for rows and total,20per page. These functions and `read_finance_gate` are denied to anon/service_role and executable by authenticated sessions only; each derives actual scope internally.

Routes `/finance` and `/finance/:term/:request` show personal drafts/submissions and eligible private history. Ordinary FIN request links redirect to this typed page after an authorized read; authentication return paths preserve the exact finance case path and strip query values. The role-gated FIN navigation label grants no extra access. Review authority is still unavailable until P26; no private reviewer cases are inferred from service heads, beneficiary identity or role labels. P24's currently eligible participant is the admitted requester.

The form captures all six case kinds, private title, purpose, fund, current same-term beneficiary, optional deliverable/planned/requested dates, terms/risks/school requirements, bounded cost lines, price and sales forecast. PHP text uses exact BigInt/string calculations. A partial/invalid line gets a field error and no invented total. The configured request form still owns its ordinary envelope and exact final-file selections; its optional currency adapter is supplied by P24's trusted typed total. The typed page hides generic draft-save, so it cannot claim the itemized draft was persisted. Finance edits are explicitly identity-bound **memory only until confirmed submission**, cleared on sign-out/account change; there is no raw private browser storage. Existing finalized-file upload and byte reauthorization are reused.

Submission always calls `submit_finance_request`, including zero-cost fundraising. Requested totals, forecasts, authorized ceilings and recorded actuals have separate labels. P25 shows no issued ceiling or actuals because those modules are absent. Submission authorizes no commitment/payment. Current configured process notes/service requirements are shown; school/evidence/authority requirements remain explicit external inputs rather than invented policy.

Conflict/validation preserves typed and configured form inputs. A lost reply locks inputs/actions and retains the exact payload/key; only explicit identical recovery is offered. Every case refresh/focus remount performs a current authorized read before displaying private contents. A newly confirmed revision has immutable history and exact selected downloads. Historical view is read-only for requester mutations; return to the current case before revising/cancelling. Submitted totals are labeled separately from new draft calculations.

`read_finance_gate(term,work)` independently requires detail access to the requested task/deliverable and returns **only** `{state:'pending'|'not_verified'}`. For a task, lookup of a linked deliverable additionally requires current parent detail access; the task grants none. A permitted linked current typed plan can produce pending; no plan, insufficient parent scope, unconfirmed policy or unavailable read never implies approval. Task/deliverable panels include no case ID, financial title, amount, receipt, count or private link. These are provisional safe signals; P26 owns revision-bound authorization outcomes. No authorization, ledger or actual-payment logic is installed.

Named isolated SQL/frontend/browser P25_A1–A3 and limits are recorded in `docs/build/steps/P25.md`. P26 is separately code-eligible and has not started. All inherited institutional/privacy/provider/JWT/concurrency/human gates remain.

## P26 typed FIN authorization

Migration034 adds six forced-RLS/direct-grant-denied tables: `finance_authority_designations`, `finance_authorization_policies`, `finance_review_bindings`, `financial_authorizations`, `financial_authorization_events`, `finance_case_metadata`. **No institutional designation, policy, role grant or waiver is seeded.** Provisioning requires separately verified institutional authority; this slice provides no browser configuration shortcut. Isolated fixtures explicitly label their records fictional.

The current adapter maps an explicitly confirmed **single-stage, one-reviewer, terminal FIN workflow** with a named primary authority. Policy pins request type/workflow version, stage, primary designation, effective dates, institutional reference and external requirement (`required` or `not_required`). Unsupported/sequential/all-reviewer financial routing stays paused. Actual institutional routing must be confirmed; if it differs, its typed mapping must be extended before activation. No proposed endorsement or PM default is silently substituted or removed. This is a bounded local adapter, not a claim of arbitrary workflow support.

An official designation pins an exact role-assignment version, same-term confirmer, institutional reference, dates and optional `alternate_for_id`. Eligibility additionally requires current same-unit `finance.review`, deployment, core/workspace admission, active organization/unit/term/person and current dates. Department review/PM/beneficiary labels alone grant nothing. The current requester and beneficiary cannot decide their case. A version-changed/revoked designation does not resurrect on status restoration: renewal needs a newly confirmed assignment/designation/policy as applicable.

`activate_finance_review(work,reviewer,expectedRevision,expectedVersion,reason,key)` allows the current requester or designated FIN officer to check routing. It reuses P22's canonical instance/assignment/event records, pins the exact policy through finance_review_bindings and records a pause when an official independent primary/alternate or supported policy is unavailable. P22 field/condition/manifest entry gates still apply. Missing authority never creates an assignment. Policy changes invalidate old bindings and require fresh assignment. Generic `transition_request` FIN actions remain closed and cannot issue authorization.

`decide_finance_request(work,expectedRevision,expectedVersion,action,reason,ceilingCentavos,conditions,expiresAt,externalOutcome,externalManifest,key)` accepts approve/reject/request_revision from the current independent exact-stage FIN assignee. Approve creates one immutable canonical approval_decision and financial_authorization bound by FKs to exact request/finance revision/hash, assignment, policy and decision. Requested amount/purpose stay unchanged; ceiling is a canonical centavo string between zero and the original requested total. Conditions and finite future expiry within the term are explicit. There is no invented money threshold. Reject/revision accept no approval-only fields; revision routes back to the pinned stage. No general_approved outcome or payment is fabricated.

External `not_required` is accepted only from the confirmed policy, never a browser waiver. Required policy accepts pending (not ready) or deliberate verified evidence equal to the exact selected finance manifest. `change_financial_authorization(authorization,kind,reason,manifest,expectedVersion,key)` appends an explicit revocation or exact external-evidence verification by a current independent FIN officer. Different evidence requires a governed revision; no source manifest or old authorization is rewritten.

Authorization state is derived: valid / pending_external / expired / revoked / superseded. New governed request revisions (or explicit revision drafts/cancellation), newer policy, current authority loss, expiry and revocation remove current readiness while preserving the original decision/ceiling/hash/purpose/conditions. Required pending external evidence never becomes valid readiness. `update_finance_metadata(work,contactLabel,expectedVersion,key)` changes only an explicitly excluded administrative contact label, with its own version/audit; it never changes the governed hash/evidence or issues new authorization. All other governed changes use a new request/finance revision. Approved FIN cases can begin that revision explicitly.

Commands serialize canonical work/instance rows, current authority/deployment/role/permission rows and a policy advisory lock also acquired by policy insertion. READ COMMITTED is required. Exact actor/key/payload retry rechecks current scope and returns the original receipt; changed payload fails. Unique assignment decisions, composite FKs and same-transaction decision/authorization/state/audit/idempotency/outbox protect against conflicting transitions and late failures. These are local implementation/constraint checks; true independent provider-session races remain unverified.

`read_finance_review(term,work)` exposes minimal routing metadata to the current requester or explicitly designated scoped FIN staff. Only the current requester or current independently assigned reviewer gets the typed private snapshot, authorization and virtual exact-revision file context. Reviewers get no prior revision packages merely from historical participation. `list_finance_reviews(term)` exposes at most100 authorized metadata rows with tracking/state, never private titles/amounts/files. P24's audited `read_finance_revision` now supports this exact current reviewer entitlement; requester history remains independently scoped. Every file byte request repeats current assignment, policy, role, revision and selected-manifest checks. Raw tables remain closed to authenticated/anon/service_role.

`/finance/reviews/:term/:request` provides explicit routing/decision/partial ceiling/conditions/Manila expiry/external outcome/revocation/metadata views. FinDecisionMemory is identity-bound and memory-only: conflicts retain fields, uncertain replies lock actions and recover identical commands without optimistic authorization. The personal finance view distinguishes original requested, recorded ceiling/state and actuals; no payment/ledger exists. Shared work receives only pending/not_verified/authorized; authorized requires every currently linked typed plan to have current valid authorization, and grants no private metadata or overall deliverable acceptance.

P26 isolated SQL/compiled-browser evidence and limitations are in `docs/build/steps/P26.md`. Real Supabase17/Auth/Storage/JWT, independent concurrent sessions, approved institutional designation/routing/external evidence policy/privacy/retention and human/mobile/keyboard/assistive-technology acceptance remain gates. MCD remains closed. P27 has not started.


## P27 optional reservation ledger and documented actuals

Migration035 adds budget_accounts, budget_entries, actual_finance_records and actual_finance_events (forced RLS, raw grants denied, immutable history). FIN policy pins optional immutable budget_account_id and explicitly opts into reconciliation_enabled (default false). No actual account/ceiling/authority or institutional policy is seeded. Approved primary/alternate/reconciliation authority, fund/ceiling/custodian and privacy/evidence policy remain external inputs; P26's supported routing limit persists.

An authorization atomically reserves ceiling minus case-wide booked expenses against a matching configured account, before canonical command commit. Account locks serialize available-budget checks and every entry insertion. Insufficient funds roll back the entire decision/key/audit/outbox. Per-entry guards validate policy/account/reversal identity and nonnegative available and reserved balances. Available = ceiling minus reserved minus booked expense; recorded revenue does not raise it. Reservations from expired/superseded/revoked authorizations remain held until explicit release. Replacement decisions require release of outstanding prior reservations. Approved typed FIN request cancellation releases all unspent reservations once, under ordered locks; explicit FIN commitment cancellation also revokes. Booked expenses remain charged. A reversal refunds booked use once and never recreates a commitment. No mutable balance field, destructive correction or payment integration exists.

record_finance_actual(work,expense|revenue,centavos,evidenceAsset,reference,on,reason,version,key) requires current independent assigned FIN authority plus explicit reconciliation policy, current valid authorization, positive integer PHP centavos and finalized same-case uploaded bytes/hash. Dates are in-term and not future in Manila. Case/term/kind duplicate evidence SHA or normalized reference is rejected, including reversed records; differently scanned documents still require human duplicate checks. Expenses exceeding current case ceiling or available budget remain documented requires_review records without booking. Only a new valid authorization may book them through reconcile_finance_actual(record,book|reverse,reason,version,key); reversals are append-only events/linked entries. Current scope/version, actor/key/payload, canonical locks, redacted audit and outbox are atomic. Requested, authorized, reserved, booked, projected revenue and actual revenue are separate.

read_finance_ledger(term,case) is audited and limited to current independent assignee and policy opt-in. It returns restricted case totals/latest100 actuals/evidence/held commitments, not a general core report. Requester/general head/member cannot read ledger balances or receipt references. Approved case receipt upload/finalization is a narrow P12 file-only extension for admitted requester/current FIN assignee; it never changes the plan hash/selected manifest or broadens request editing. Current receipt candidates and recorded historical receipts download via current virtual review context with live scope rechecks. read_finance_gate remains exactly a neutral state; unresolved actuals or closed current commitments keep readiness pending without exposing balances/receipts/case metadata.

Reconciliation.tsx is embedded in existing FIN review, with validated ledger-api receipts, identity-bound memory and identical frozen uncertain retry. Receipt-only Files controls and exact same-name hash prefixes prevent accidental source editing/ambiguous selection. Current roles/policy/assignment revocation remove ledger/actions/downloads. P27.md records actual local checks and all inherited provider/JWT/independent-concurrency/institutional/privacy/retention/human gates. Earlier P24-P26 statements about absent ledger/actuals are historical; P27 supplies this local adapter only. No live configuration is activated; no P28 implementation.

Implementation references checked: [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) and [PostgreSQL17 explicit locking](https://www.postgresql.org/docs/17/explicit-locking.html). These describe primitives, not evidence of this application's provider/session verification.
