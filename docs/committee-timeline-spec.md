# Committee timeline: approved P16A scope

The user approved preparing P16A for a committee Gantt feature on October 24, 2026. This addendum extends F03/F04/F05 in the original implementation plan. It does not mark the feature implemented or alter the active build ledger. Execute after P16 and before P17; later IDs and P17's code prerequisites remain unchanged.

## Goal and limits

Heads and core members can see permitted committee commitments across time, their owners and dependencies. One canonical deliverable, accepted contribution or task appears once in the combined view. The timeline reads the same records used by existing work pages; it is not a second scheduling system.

The first chart is read-only. Existing authorized forms own date changes. No drag-to-reschedule, automatic successor shifting, critical-path/capacity calculation, progress percentage or new approval workflow. Overlapping bars are commitments, not proof of overload. Calendar meetings, room bookings and Google synchronization stay in their owning prompts. No paid chart dependency is authorized; prefer the existing stack and native HTML/CSS/SVG where sufficient.

## Dates and mutations

Use an existing equivalent to nullable work_items.planned_start_on, otherwise add this date-only field. It means a planned Manila calendar day, not actual work start or created_at. Never fabricate historical starts. Existing due_on/due_at remain authoritative; derive a display end day from due_on or the Asia/Manila date of due_at without rewriting the stored deadline. Preserve original_due_on/original_due_at and existing change reasons.

- Start and end: bar includes both calendar days; equal-day work is valid. Reject start after end server-side, including when an existing command later changes the deadline.
- End only: labeled deadline marker, with no implied duration.
- Start only, or neither: separate unscheduled list stating the missing dates, with no invented finish. Render no fabricated bar.
- Explicit milestones may use existing milestone metadata if available; a deadline marker is not proof that the work is a milestone or accepted.

Use calendar-date arithmetic and test Manila midnight, month/year edges and leap day. Today and the April 17, 2027 event marker use Manila time. Display ranges must not turn inclusive deadlines into previous-day bars or hide already overdue incomplete work.

Scheduling authority must match the existing server rule for date edits, including frozen/archived/guest restrictions. Own progress rights do not imply permission to reschedule. Reuse an existing safe command, or add update_work_schedule(work ID, planned start, expected version, request UUID) that only changes planned start under that rule. Actor derives from auth.uid; real changed-row/version/audit and idempotency checks are required. No due-date, agreement or approval changes through this helper. If an accepted agreement governs the changed field, use its existing revision/confirmation flow; do not silently amend the accepted contribution. Stale/rejected saves preserve unsent form input.

## Projection and authorization

read_committee_timeline(term ID, filter JSON, page=1, page size=50) returns JSON with items, total, page, pageSize and permitted dependencies for the loaded rows. Validate filter names/UUIDs/dates/enums, cap page size at 100 and use deterministic ordering with a unique work-ID tie breaker. Apply current access before filtering, pagination and aggregation. Range filters include intersecting dated work; retain an explicit way to see unscheduled work independently of the visible date window.

Each item needs stable canonical work ID/type, safe title/detail route, owner display fields, primary unit and permitted participating units, phase/status, planned start/end dates, original target fields if permitted, overdue/blocked indicators and version. Preserve nulls instead of invented owners/committees. For a contribution, use its real P14 work identity and receiver unit; follow the actual established subtype mapping, never fabricate an independent work item for a chart row.

The primary lane follows the record's lead/assigned/receiving committee according to its established type. Other permitted units are participation badges. Selecting multiple committees or being deployed to several units never duplicates the work or its totals. Unit membership or a linked parent does not expand record access. Only draw P16 edges when both endpoints are permitted and loaded; distinguish required finish-to-start from informational links. Do not expose hidden IDs/counts or imply that the displayed partial graph is complete. Reuse only P16's permitted neutral blocked indication for restricted predecessors.

Filter options, owner/unit labels, totals, row order and errors must not reveal restricted records. Ordinary-summary access is not permission to show confidential task/contribution details. The new core committee view/RPC is unavailable to guests; existing exact-scoped shared-record routes continue independently. Revocation/expiry is rechecked on database requests and UI revalidation, not trusted from a cached chart.

## Interface and verification

Place Committee timeline under Working together and link from Core Deliverables. Reuse Karla, calm panels, interface accent, focus language and 44px controls. Week/month scales, previous/next/today controls and committee/owner/phase/type/blocked/overdue filters operate on the same permission-filtered data. Keep filter/page state in safe URL parameters; no bearer/private payload in URLs.

Bars and markers open real record details; date edits open existing forms. Provide a chronological list/table for keyboard users, narrow screens and 200% zoom, exposing the same loaded records, dates, owners, text statuses and permitted dependency descriptions. Do not rely only on color/hover/dragging. Scope timeline scrolling to its region rather than causing page overflow. Include loading, unscheduled, empty, error/retry and access-changed states. Label pagination and partial graph coverage honestly.

Named P16A_A1–A3 in the prompt require authenticated database regressions, actual changed-row assertions, meaningful date tests and browser captures. Synthetic fixtures are development/test only; disconnected production does not show them as real committee commitments. Existing FIN/MCD/acceptance rules and P02 onward external verification gates remain. Execution must record docs/build/steps/P16A.md and update STATE/contracts; preparing this prompt does neither.
