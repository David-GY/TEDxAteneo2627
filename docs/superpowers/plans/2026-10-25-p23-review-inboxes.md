# P23 review inbox implementation plan

> **Execution:** Single existing checkout/branch; no agents/chats/worktrees.

**Goal:** Scoped department triage and exact-revision reviewer screens with honest server outcomes.
**Architecture:** Add narrow queue/triage reads and append-only operational triage events around P22. Preserve package scope; UI uses current P22 commands and identity-bound in-memory pending-command recovery. Add overview reviews using the same authorized row predicate.
**Tech Stack:** Existing React/TypeScript/Vite/PostgreSQL/PGlite/Playwright.
**Spec:** build-prompts/23-review-inboxes.md; named F02/F08/section4; P22/P18 contracts.

Baseline3%/reset1792957207, weekly0%;40pp allocation, wind-down38%/ceiling43%. Clean1830a5a/e6c53744fe5c625bb46bf97e268788ddb6a5415e matches fetched remote. Trigger arrived22:39 Manila, later than requested13:47; use actual run time, not fabricated punctuality.

Simulated product/security/skeptical perspectives (one assistant): a head needs minimal queue metadata for assignment, while an associate needs only current assigned cases. Broad work grants are a credible simpler alternative but would expose private payloads and are rejected. Keep package preview independently authorized through P22. Accepted dates are explicit independent head commitments, never requested-date overwrite or FIN/MCD approval. Shared triage notes stay in a separate bounded append-only store with no raw text in audit/outbox/receipts. Completion is an explicit general operational action after exact-revision general approval, not a fabricated review vote. Unknown actual institutional authority remains gated.

- [x] Migration031: queue/count predicate, metadata/read extensions, current eligible reviewers, append-only triage notes/date/completion with CAS/exact retry and atomic audit/outbox. Scope denial and P22 regression tests.
- [x] Inbox/detail UI, assigned/lost-authority routing, fixed reasons/actions/evidence/date/history; preserve inputs/uncertain exact retries and no optimistic success. Existing design/components; mobile/keyboard.
- [x] Overview actionable reviews and owner revisions using same predicates; routing/navigation and preview wiring. Scoped counts, no private title in manager-only queue.
- [x] P23_A1–A3 SQL/UI/browser, P22/P21/P18 regressions, required typechecks/lint/build/generated types; review/custody/checkpoint with exact inherited blockers. Stop at P23.

Named local A1–A3 and146frontend tests and checks pass; prior failures/corrections and exact inherited blockers recorded in P23. Final custody is checked after commit/push.

Implementation83e8219 pushed; local/fetched/live remote SHA/tree matched and porcelain empty. Custody receipt committed/pushed with final verification repeated; one-time automation deleted. No P24.
