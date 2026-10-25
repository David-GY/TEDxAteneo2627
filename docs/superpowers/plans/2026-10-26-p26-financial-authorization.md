# P26 Financial Authorization Implementation Plan

> **Execution:** Existing checkout/branch, in-session review; no agents/chats/worktrees.

**Goal:** Exact-revision independent FIN decisions with partial ceilings, external-policy evidence and invalidated old readiness.

**Architecture:** Explicit unseeded institutional designation/policy records constrain typed FIN commands using P22 instances/assignments/decisions. Immutable authorizations/events derive current state from revision, expiry, revocation and current authority. Generic FIN review stays closed.

**Tech Stack:** Existing PostgreSQL/PGlite, React/TypeScript and browser tests.

**Spec:** build-prompts/26-finance-authorization.md; implementation plan F09 and section6 material-change rules; docs/finance.md.

## Global Constraints

- No requester/beneficiary self-approval or PM substitute. Official alternate and external/not-required policy must be explicit.
- Exact centavo strings, immutable requested amount/payload/evidence; partial ceiling never edits the request.
- Current actor/role/deployment/policy, expected revision/version, identical retries, atomic audit/outbox and private downloads.
- No real data, deployment, paid/provider/billing/reset change or external messages. All inherited gates persist.

## Review Focus

- Sole approver's own case and lost authority must pause rather than widen access.
- Every governed revision must invalidate prior readiness without changing original decisions.
- External waiver cannot be supplied by the browser; evidence must be the exact selected manifest.
- Approve/reject/retry races must serialize on canonical work/instance and assignment uniqueness.
- Excluded contact metadata must remain outside the governed hash, with its own audit/version command.

## Tasks

- [x] Write failing P26_A1–A3 domain assertions; add designation/policy/authorization/event/metadata schema and typed commands.
- [x] Verify local independence, alternate, partial ceiling, exact evidence, expiry/revocation/supersession, metadata and rollback/retry assertions.
- [x] Add scoped FIN decision/view and exact uncertain-retry behavior, reusing P25/P12.
- [x] Run appropriate SQL/browser/frontend regressions and required checks; record provider/concurrent-session/human limits.
- [ ] Review, checkpoint, commit/push and verify live remote/tree/clean custody. No automatic P27.
