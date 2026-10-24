# P08 deliverables reading implementation plan

> **Execution:** Existing checkout/branch, no agents or worktrees. Local implementation and reviewed commit/push authorized.

**Goal:** Permission-filtered deliverable list/detail with stable links, filters/pagination and honest provisional gates.

**Architecture:** Extend P07 fixed deliverables child, add same-term planning unit associations, read-only SQL projections returning authorized metadata/options/counts. React list/detail consume real RPCs; a clearly labeled isolated PGlite loopback preview runs only from scripts, never from production routes.

**Tech Stack:** Existing React/TypeScript/Vite/Supabase/pnpm/PGlite; preserve versions.

**Spec:** F03 and section4 Core Deliverables; build-prompts/08-deliverables-reading.md; BUILD-CONTRACT.

## Constraints / review focus

- RLS/no direct mutations; restricted rows/counts/filter options/private detail must not leak.
- One canonical output across lead/support units; no implied accepted cross-unit commitment.
- Server date logic in Asia/Manila; stable UUID detail links and URL-backed filter/page state.
- Readiness/FIN/publicity/acceptance provisional until P29; no fabricated approval/percentages.
- Synthetic data only; all P02–P07 provider/privacy/human gates retained.

## Tasks

- [x] Migration011_deliverables.sql: bounded child fields, planning unit FK/RLS, safe list/detail RPCs and named SQL regression assertions. Guarded seed adds one fictional output without breaking historical migration-boundary tests.
- [x] Deliverables api/list/detail/route modules: validated real RPCs; all required fields; URL filter/pagination state; mobile rows; loading/error/empty/denied recovery.
- [x] Dedicated loopback synthetic DB preview plus browser verifier: real SQL changes visible after reload, stable deep links/filters and 320px reflow. No fixture/auth bypass ships in production.
- [x] Required SQL/unit/typecheck/lint/build, relevant regressions, diff review and checkpoint/state/contracts. Commit/push/fetch exact remote tree.
