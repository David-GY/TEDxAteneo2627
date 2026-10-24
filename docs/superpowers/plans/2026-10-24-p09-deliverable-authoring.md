# P09 deliverable authoring implementation plan

> **Execution:** Existing checkout and authorized branch; no agents/worktrees. Reviewed checkpoint commit/push authorized.

**Goal:** Scoped create/propose/edit/reassign and versioned lifecycle commands with fail-closed acceptance.

**Architecture:** Extend fixed deliverables child and P07 transaction/idempotency/audit/outbox helpers. Fixed immutable revisions and trusted-only gate applicability attestations keep content, criteria, deadline reasons and final evidence attributable. Real routed editor consumes authoritative options/actions; the existing isolated preview gains only explicitly allowed synthetic command transport.

**Tech Stack:** Existing React/TypeScript/Supabase/PGlite/pnpm, no dependencies.

**Spec:** build-prompts/09-deliverable-authoring.md; F03 and section6 create_deliverable; BUILD-CONTRACT and DESIGN.md.

## Constraints / review focus

- Current scoped committee.manage authorizes heads; ordinary members propose only themselves. No inferred authority from affiliation or head label.
- Generic P07 draft commands must not bypass P09 deliverable requirements; keep their historical regression boundary explicit.
- Same-term active owner/unit, required phase/outcome/date/criteria, original date preservation, reasoned changes, stale-version/idempotency rollback.
- Owner departure yields a derived authorized reassignment queue without deleting historical owner.
- No self-acceptance, unresolved mandatory gates or stale gate assessments; trusted-only clean-case fixtures do not implement P29/provider approval.

- [x] Add migration012 commands, immutable snapshots/gate checks and authoring options/queue; named P09_A1–A3 assertions plus retry/stale/bypass regressions. Run targeted SQL and regenerate types.
- [x] Add typed command adapter and editor embedded in existing list/detail, real option/action permissions, explicit pending/error/conflict/retry behavior and mobile form. Add meaningful frontend assertions.
- [x] Extend clearly labeled synthetic live preview and isolated browser checks for actual propose/create/edit/lifecycle/blocked acceptance and 320px reflow; inspect captures.
- [x] Run required checks and relevant regressions, detector/diff review, update contracts/state/P09 evidence and usage. Commit/push/fetch exact remote commit/tree and clean worktree.
