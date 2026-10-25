# P27 finance ledger implementation plan

> **Execution:** Same checkout, no agents/chats/worktrees. User authorized reviewed commit/push.

**Goal:** Optional atomic budget reservations and evidence-backed actuals without processing payments.
**Architecture:** Pin an optional immutable budget account to a versioned FIN policy. Authorization insert reserves under an account lock; cancellation or explicit FIN closure releases unspent reservation once. Immutable actuals/events/ledger entries record bookings, review flags and reversals. Current independent assignee alone reads the restricted case ledger; general work receives only the existing neutral gate.
**Tech Stack:** Existing React/TypeScript/Vite/Supabase/PGlite; no dependencies.
**Spec:** build-prompts/27-finance-reconciliation.md; implementation plan F09/F21 and section8 ledger.

## Global constraints

- Integer PHP centavos; requested/authorized/reserved/booked/forecast/actual distinct; no payments.
- No actual account, policy, authority or institutional configuration seeded.
- Existing Karla/neutral/#b82320/44px/focus; synthetic SQL/PNG preview only.
- Current independent FIN authority, exact policy/revision, expected version, identical retry and audit/outbox remain required.
- Provider/JWT/independent concurrent sessions/privacy/human gates remain unverified.

## Review focus

- Two requests sharing one account must lock before testing available ceiling; no revenue automatically increases budget.
- Cancellation/release/reversal retries cannot credit twice or erase history.
- Evidence hash and reference deduplication spans cases; unselected/unfinalized/foreign receipts fail.
- Recorded overrun remains visible, blocks readiness and requires a new review before booking.
- Lost authority hides ledger/receipt contents; requester/general core receives no balances.

## Tasks

- [x] Domain red/green: migration035 finance_ledger; SQL fixture and P27_A1-A3 regression assertions for reserves, releases, evidence, actuals, overrun/re-review and reversals.
- [x] Restricted reconciliation read/commands and actual-evidence download, wired into current FIN review. Identity-bound exact retry memory; native controls and safe gate.
- [x] Compiled browser checks, SQL regressions, frontend tests/typechecks/lint/build/catalog; explicit independent-concurrency limits.
- [ ] Reviewed mandatory checkpoint, commit/push, exact remote/tree/clean custody and visible preview. No automatic P28.
