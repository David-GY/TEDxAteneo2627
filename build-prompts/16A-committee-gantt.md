# P16A — Build the permitted committee Gantt timeline

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P16A: Build the permitted committee Gantt timeline.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F03/F04/F05; section 4 Core Deliverables and Working Together; section 8 work_items, contributions and task_dependencies.
Also read docs/committee-timeline-spec.md (approved P16A scope and date/access contracts); existing docs/tasks.md, docs/deliverable-authoring.md and docs/synergies.md if present, or their recorded equivalents in docs/build/CONTRACTS.md.
Code/interface prerequisites: P07, P09, P10, P15, P16. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/timeline/*; src/features/tasks/TaskEditor.tsx and existing task DTO/command paths; existing deliverable editor/DTO/command paths; src/features/synergies/*; src/app/router.tsx; src/app/navigation.ts; supabase/migrations/*committee_timeline.sql; supabase/tests/committee_timeline.test.sql; scripts/test-committee-timeline.cjs; src/lib/database.types.ts; docs/committee-timeline.md; docs/build/CONTRACTS.md

Interfaces / invariants:
Optional work_items.planned_start_on is a Manila calendar date, never inferred from created_at. Reuse due_on/due_at and original deadlines; do not duplicate the work model. read_committee_timeline(p_term_id uuid, p_filters jsonb default '{}', p_page integer default 1, p_page_size integer default 50) returns a bounded permission-filtered JSON projection, one item per canonical work ID and only permitted dependency endpoints. If existing commands cannot safely set planned start, add update_work_schedule(p_work_item_id uuid, p_planned_start_on date, p_expected_version integer, p_request_id uuid) using the existing scheduling authority, audit/idempotency/version conventions; it cannot change due dates, accepted agreements or approvals. The chart is read-only; schedule edits happen in existing authorized forms.

Keep a live local preview visible throughout implementation. Extend the existing Karla/design system, not a redesign. This prompt authorizes committing and pushing only reviewed P16A changes/checkpoint to the existing codex/core-build-checkpoints branch; preserve unrelated staged/working changes and verify the remote backup. No website/provider deployment, external messages or paid dependencies. Run after P16 and before P17 without renumbering other prompts. Preparing this file did not execute P16A or supersede the current active build step.

Implement and verify this bounded slice:
1. Verify current P07/P09/P10/P14-P16 interfaces. Add planned_start_on only if no equivalent exists, with nullable/no fabricated backfill semantics and server validation against existing due_on or Manila date of due_at. A start without an end stays unscheduled. Expose planned start through existing authorized task/deliverable forms with expected version, stable retry key, redacted audit and preserved original deadlines; assignee progress rights do not become scheduling rights. Existing deadline-changing commands must also reject a deadline before planned start. Use the approved agreement revision flow for any governed dates; do not create a rescheduling bypass or edit accepted contribution deadlines.
2. Implement bounded paginated read_committee_timeline from canonical deliverables, accepted contributions and tasks. Apply current authorization before filters, joins, totals, committee/owner choices and dependency projection; ordinary-summary access does not reveal restricted details. Derive one primary committee lane and participating-unit badges per record. Required versus informational edges use P16 semantics; draw links only when both endpoints are visible/permitted, with no hidden titles, IDs or counts. Keep guests excluded from the new committee projection; existing exact shared record links retain their own rules.
3. Add Working together -> Committee timeline, plus a Core Deliverables link. Provide week/month scales, previous/next/today controls, Manila today and April 17, 2027 markers, committee/owner/phase/type/blocked/overdue filters, readable status labels, deadline markers for end-only work, unscheduled list for incomplete dates, and links to existing records/edit forms. Use an accessible chronological list/table at 320px and 200% zoom; keyboard users can reach all filters and records without dragging. Preserve chart/list filter and pagination state, show loading/empty/error/retry/access-revoked states and explain that only loaded permitted rows/links are shown. No automatic date shifting, drag/resize, critical-path/capacity algorithm, invented percentage-complete or approval badges. Regenerate types, document date/access contracts and show only clearly fictional development/test fixtures when no connected backend exists.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P16A_A1: Under authenticated ordinary member/head/nonmember/expired or revoked member/guest and cross-unit fixtures, restricted rows, endpoints, IDs, titles, lane/filter metadata and totals never leak; direct RPC/deep links cannot bypass current access. A multi-unit task or shared contribution remains one canonical result under combined filters and pagination. Losing access removes previously visible data on refresh/revalidation.
- P16A_A2: Named date/command regressions assert null dates remain unscheduled, end-only work is a deadline marker rather than a fabricated duration, start-only work has no invented finish, equal-day ranges are valid and reversed ranges fail through both schedule and existing due-date commands. Cover Manila midnight from timestamp deadlines, month/year boundaries and leap day without off-by-one bars. Authorized date change updates the actual row/version/audit once; retry, stale version, unauthorized assignee and accepted-agreement changes cannot bypass scheduling rules. Original deadlines and FIN/MCD/acceptance state remain unchanged.
- P16A_A3: With an actual local browser and explicitly fictional fixtures as needed, week/month/today navigation, filters, correct detail links, visible dependency versus informational labels, unscheduled/empty/error recovery and revoked-session handling work. At 320px and 200% zoom the chronological alternative exposes the same loaded permitted records without page overflow, with 44px controls, meaningful names, keyboard focus and text status cues. No fake data appears as real production work; no chart gesture mutates a schedule. Record actual commands/results and screenshots; provider/human checks that cannot run remain blocked, not passed.

Update docs/build/steps/P16A.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
