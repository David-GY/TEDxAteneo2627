# Committee timeline Implementation Plan

> **Execution:** Follow the user-authorized execution method with available tools.

**Goal:** Complete the approved read-only P16A committee timeline using canonical work.

**Architecture:** Nullable planned start on existing work; narrowly authorized schedule command and due-date guard; permission-first paginated projection; read-only native chart with chronological alternative. No duplicate work model or paid chart library.

**Tech Stack:** Existing React/TypeScript/Vite/Supabase SQL/PGlite.

**Spec:** build-prompts/16A-committee-gantt.md and docs/committee-timeline-spec.md; named F03/F04/F05/sections4/8.

## Global Constraints

Existing branch/checkout; live preview; no agents/chats/worktrees/provider changes/deployment/messages. Karla and existing design. Preserve inherited gates/original deadlines/FIN/MCD/accepted terms. No P17. Initial shared usage85%, effective5point budget; small verified checkpoint per BUILD-CONTRACT.

## Review Focus

- Missing dates never become invented ranges; timestamp end uses Manila day.
- Permission precedes lanes/options/totals/paging/edge endpoints; guests excluded.
- Self-created/assignee rights cannot widen date authority; accepted contributions remain governed.
- Stale/uncertain form input and exact retry keys survive failure.
- Same loaded records at320px/200% zoom, keyboard/44px controls, no chart mutations.

## Tasks

- [x] Add/test pure calendar-date foundation for nulls, markers, inclusive ranges, Manila boundaries and week/month windows.
- [ ] Inspect current command authority and add nullable planned_start_on plus schedule-only RPC and deadline-changing command guards; named SQL A2 mutations/retries/authority tests; regenerate types.
- [ ] Add permission-first canonical timeline projection with validated filters, deduplication, permitted options/edges and named SQL A1 cases.
- [ ] Wire planned-start authorized forms and read-only week/month chart/chronological alternative, filters/navigation/markers/unscheduled/revalidation; named A3 browser checks.
- [ ] Run required/relevant checks, review render/privacy/error paths, update contracts/STATE/P16A, commit/push and verify custody.
