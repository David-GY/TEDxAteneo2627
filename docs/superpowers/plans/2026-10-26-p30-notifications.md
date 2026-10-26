# P30 in-app notifications implementation plan

> **Execution:** Existing checkout only, no agents/chats/worktrees. User authorized reviewed checkpoint commit/push.

**Goal:** Deduplicated currently authorized in-app updates and reliable isolated after-commit dispatch.
**Architecture:** Existing transactional outbox gains bounded leases/retry/dead-letter state. Opaque event/recipient references are stored without titles, amounts or private bodies; reads resolve authorized current targets and action state using existing work/agreement/handoff/request scope. A service-only worker claims and processes committed jobs; business transactions never call dispatch. External adapters stay disabled.
**Tech Stack:** Existing React/TypeScript/Vite/Supabase/PGlite; no dependencies/provider changes.
**Spec:** build-prompts/30-notifications-inapp.md; F19 and section6 outbox contracts.

## Constraints and proportional simulated review

Product: alert actual participants and reviewers, avoid committee-wide chatter; distinguish resolved updates from actionable work. Security: current source access before text/link/count, generic text only, no JWT impersonation in dispatcher. Skeptical: crash/lease retry and late failure must not duplicate delivery or undo decisions; a simple polling-only UI alternative cannot demonstrate reliable persisted failure. Proceed with a bounded leased worker and opaque references. These are one assistant's simulated perspectives, not independent reviewers.

- [x] Red/green P30_A1 crash/retry/dedup, A2 committed decision/failure/custodian, A3 revoke/read/link denial.
- [x] Migration038 job leases/retries, private selectors, scoped inbox/read-state/preference skeleton/custodian RPCs and due/overdue enqueue; no external adapters.
- [x] Bounded authenticated Edge dispatch handler, inbox/badge/preferences/failure visibility, actual SQL preview and browser regressions.
- [x] Required tests/type/Edge/lint/build/catalog, review, mandatory STATE/P30/custody, visible retained preview and commit/push/live tree/clean verification.

No real custody policy is seeded. Explicit term admin.configure maps queue custody only; no private case content. Worker deployment/secret/schedule and real provider/JWT/concurrent/human/privacy acceptance remain external gates. Immediate/digest/mute preferences are skeleton controls; required in-app work remains visible regardless of preference. Future external delivery and configurable reminder policies remain out of scope.
