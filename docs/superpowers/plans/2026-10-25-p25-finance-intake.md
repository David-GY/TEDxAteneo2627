# P25 Finance Intake Implementation Plan

> **Execution:** Existing checkout/branch; no agents, chats or worktrees.

**Goal:** Provide itemized finance intake, confidential case history and neutral shared-work gate summaries.

**Architecture:** Extend the established request forms/routes with P24's atomic command and requester-only reads. Add narrowly scoped list/intake/gate projections; P26 review authority remains closed.

**Tech Stack:** Existing React/TypeScript/Vite, PostgreSQL/PGlite and browser tests.

**Spec:** build-prompts/25-finance-intake.md; implementation plan F09 and section6 FIN defaults; docs/finance.md.

## Global Constraints

- Existing Karla/neutral/red tokens,44px controls, visible focus, native labels and mobile reflow; no redesign/dependency.
- Exact string money; requested/forecast/authorized/actual stay distinct. Zero-cost fundraising requires FIN review.
- No confidential data in ordinary task/deliverable summaries, logs, browser storage or URLs. Current scope rechecked on every read/file/action.
- Identity-bound in-memory inputs; version conflicts preserve edits; uncertain results retry identical key/payload without optimistic success.

## Review Focus

- Partial/invalid line edits must show useful errors, never stale invented totals.
- Zero revenue/cost and negative margin remain plans, not approved/actual money.
- Shared-task links must never expose case title/amount/receipt/identifiers/count.
- Remounts, revocation and late replies must not restore obsolete private data.
- School requirements remain explicit configuration inputs, never invented institutional approval.

## Tasks

- [x] Write failing exact form and scoped SQL tests; implement missing intake/list/gate read seams.
- [x] Build typed draft fields, exact recomputation, P24 command/retry memory, confidential revision page and scoped desk.
- [x] Integrate catalog/request deep links, auth returns, file selection/download and safe task/deliverable summaries.
- [x] Verify P25_A1–A3 plus conflict/uncertain/revocation,320px/keyboard/browser checks; required typechecks/tests/lint/build/catalog.
- [ ] Review in-session; record evidence/STATE/contracts/checkpoint, commit/push and verify live remote/tree/clean custody. P26 requires separate authorization.
