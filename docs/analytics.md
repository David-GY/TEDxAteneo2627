# Reports and minimal activity measurement (P44)

Status: in_progress. Source054 delivers the first scoped work/weekly-activity batch. Queue age and handoff/approval turnaround are not implemented. No production telemetry policy, cleanup schedule or deployment is enabled.

## Scope and definitions

`read_reports(term,week,unit,filters)` requires current core workspace.read and reports.view. Operational rows additionally require current committee.manage for the work's lead unit and can_access_work(detail). Only unarchived ordinary tasks/deliverables enter aggregates or source links. Restricted work, raw requests, finance, evaluations, profiles, bodies and attachments are excluded, including when a head separately has a private record grant. Reporting authority never grants source access. A unit outside the caller's current scope is denied; all supervised units form a union without duplicate work.

The report states its server refresh date/time and Manila timezone. Operational measures are a current snapshot, not a reconstructed historical week. The selected Monday–Sunday period applies to activity. Closed filters are all, overdue, blocked and unassigned; unsupported keys/types reject. At most50 source rows are returned with UUID-keyset paging; authorization and aggregate scope repeat on every call. Canonical title/reference links retain the term, including through sign-in recovery. No export endpoint or per-member ranking exists.

| Measurement | Definition |
| --- | --- |
| Open work | Scoped work outside done/cancelled; accepted deliverables needing P29 re-review remain open. |
| Overdue now | Open work past its current timestamp, or past its untimed Manila due date. |
| Original deadline missed | Open work past its preserved original deadline, even when its current deadline moved later. This is not a late-completion trend or a cancellation analysis. |
| Blocked tasks/duration | Current blocked tasks; continuous recorded blocked interval begins after the latest non-blocked task revision. Calendar days derive from immutable revision times. Missing history stays unavailable; updated_at is not a substitute. Pauses/business-day calendars are not inferred. |
| Assigned/unassigned open tasks | Counts of scoped open task assignments. No inferred effort, utilization or productivity; individual workload breakdowns are closed. Current/original due dates are available in source rows. |
| Deliverable checks met | Existing P29 public readiness result projected to a boolean. It does not mean independently accepted and does not copy gate evidence. |

## Weekly activity and collection gate

Three new app_private tables hold immutable policy versions, version-bound trusted human/test/bot classifications, and minimal events. They force RLS and deny raw access to anon/authenticated/service roles. No public policy or classification editor/provisioning command is provided. Actual privacy basis, eligible population, retention approval and institutional authority must be supplied and reviewed before trusted provisioning. The migration and live synthetic preview contain no enabled policy. Provision a reviewed policy/classification set in one approved transaction; policy/revocation concurrency needs provider rehearsal before live activation.

The latest approved policy defines a new observation window. Earlier policy events are not silently replayed into a new policy's metric. Currently active core roster members must have a trusted classification; unknown coverage makes activity unavailable. Eligible humans overlap the week through joined_at/ends_at, with one count per member regardless of units. This is the currently eligible roster's overlap with the week, not a historical roster census. Events must fall inside both membership and capture intervals. The numerator counts distinct eligible humans with an allowed event in Monday00:00 through the following Monday00:00, Asia/Manila, end exclusive. Partial capture/current weeks are labelled.

The target uses exact integer arithmetic, active×5≥eligible×4. Required active members are ceil(0.8×eligible): at89 eligible,71 fails and72 passes regardless of display rounding. A zero denominator has no percentage or target verdict. Cohorts below5 disclose no exact counts; this engineering floor is not an institutional privacy/anonymity approval. Unit activity breakdowns are closed to prevent subgroup differencing. Unknown configuration, expired retention, no eligible cohort and suppression are distinct states. Nothing infers newcomer success, affiliation comparisons or sustained four-week adoption from activity.

The fixed event vocabulary is work_viewed, task_updated, synergy_proposed/responded, handoff_submitted/accepted, request_submitted, decision_recorded, onboarding_item_completed, config_published and archive_verified. Only named business-audit mappings and the fixed work-opening RPC can insert. Onboarding/archive and other module-specific capture coverage still need integration verification; reserved vocabulary alone does not prove an event is emitted.

`record_work_view(work_id)` rechecks a current permitted task/deliverable detail and derives actor, term, unit and server time. The frontend invokes it only after a visible, explicitly opened record is allowed, once per mounted page. Background scope/detail reads, focus polling, login and report refresh do not emit work views. The backend deduplicates the actor/work/Manila-week view; tests/bots/guests/unclassified actors do not record. Permission is checked before duplicate handling. No service actor may call this API. Client delivery is best effort; there is no offline queue or guaranteed attention measurement.

Action events derive from redacted authoritative audit insertions in the same transaction. An exact business retry adds no duplicate event, and a late outbox failure rolls back the event and business action together. Events contain only UUID, server timestamp, term, policy-salted pseudonymous subject key, fixed event type, opaque object/unit and deduplication key. No member name/email, comment/request body, amount, contact, token, session replay, external tracker or arbitrary client event payload is collected.

Approved raw-event retention is bounded7–90days. Service-only prune_usage_events(term) deletes at most5,000 expired event rows per call and retains current rows. No schedule is installed or activated. Periods outside the current approved observation/retention window are unavailable rather than fake zero-use weeks. Historical aggregate retention, classifier/policy lifecycle, holds/disposal, actual consent/privacy decisions and operational cleanup custody remain P46/provider inputs; policy/classification history is not automatically erased with events.

## Remaining work and verification

Queue age, unassigned review cases, handoff response/acceptance and approval turnaround still require source-specific current authorization, pinned revision/generation boundaries, honest calendar/business-time definitions and tests. Historical delivery trends, due-horizon workload summaries and comprehensive typed action integrations remain open. P44 is not complete; continue this step before P45.

Local evidence: build/evidence/P44-reports-server.json, P44-usage-server.json and P44-reports-browser.json; checkpoint build/steps/P44.md. Synthetic SQL/browser checks are not actual PostgreSQL17/JWT, independent-session concurrency, approved privacy/population/authority, human explanation/newcomer timing, native zoom/assistive or release/restore acceptance. All inherited gates remain.
