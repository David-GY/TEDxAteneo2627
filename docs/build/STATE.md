# Current build state

Updated October24,2026 (Asia/Manila).

- Current step: **P10 — blocked_external**. Local task command/editor implementation and P10_A1–A3 delivered; actual provider, concurrent-session, authority/privacy and human UAT remain blocked.
- P00/P01 complete; P02–P09 retain their blocked_external ledgers. P11–P63 not executed. Next separately code-dependency-eligible prompt: **P11 — build-prompts/11-comments.md**; do not auto-run.
- Current contracts: docs/tasks.md, docs/build/CONTRACTS.md and prior deliverables/work/permissions/guest/profile contracts. Full current/historical P10 evidence: docs/build/steps/P10.md. DESIGN.md remains visual authority.

## Delivered interfaces

Schema **30tables/369columns/39public functions**, migrations001–015. P10 adds create_task/update_task/assign_task/transition_task, read_task/read_tasks/task_options, task_collaborators and immutable task_revisions. RLS before grants; no direct writes. Work owner and task assignee are one canonical member under deferred constraints; created_by remains immutable. Created by me follows creator, not the changing owner. Current source/receiving/exact-work managers, or self-created work still owned by its creator, manage metadata. Assignees/shared editors get bounded progress; receiving a task alone does not grant deadline/assignment management. Cross-unit/person assignment requires a current receiving head with exact task edit scope. No implicit parent/sibling access or invented agreement.

Typed task states, checklist, collaborators, active same-term assignment, dates/blocker/evidence, immutable reasoned revisions, expected-version locks and exact actor/key/payload retries with transactional redacted audit/outbox. Original deadline retained; Manila date-only cutoff; completed work leaves overdue. Ordinary Done needs all checks/evidence/no blocker; review-required Done needs independent scoped review; governed Done stays closed. Task completion never grants FIN/MCD/deliverable acceptance. Generic task create/edit bypasses closed.

Real My Tasks assigned/created/shared/overdue/managed URL views and pagination; UUID detail/editor/login/guest-read scope. Saved version/time from database. Stale drafts retained; uncertain replies freeze and retry the exact key/payload; workflow actions cannot discard unsaved edits. No browser draft storage. Editor changes date-only targets and preserves existing timestamps (RPC handles reasoned timestamp edits). Existing deliverable links work with independent access; optional contribution linkage awaits its real owning interface/FK and remains closed. Evidence notes do not verify files. Comments/private files remain later steps.

P09 deliverable command/gate invariants, P08 read boundaries and earlier identity/profile/guest rules remain. No production fixture endpoint or real records.

## Actual verification

PASS pnpm test:tasks: historical migration013 R0 plus current3 named P10 assertions; targeted test:task-commands verifies duplicate receipt, owner/assignee canonical constraint, unauthorized changes/generic bypass, current receiving-head acceptance, private-parent isolation, assignee progress vs protected metadata, original/date-only behavior, independent review and governed fail-closed. Embedded PostgreSQL18.6/PGlite0.5.11 with verified-shaped subjects only; **not actual Supabase/JWT or parallel-session proof**.

PASS full-schema P09 authoring3/P08 deliverables3/P05 guests3 plus Google3/P06 directory3 plus guest-contact3. Older P02/P03/P07 boundary results retained, not claimed rerun. PASS17files/74frontend tests, typecheck/lint/build167modules (app403.53kB/gzip122.47kB, CSS11.55kB/gzip3.06kB), generated/drift-check types30/369/39. Exact commands/exits in P10-checks.txt; source hashes/TAP P10-commands.json.

PASS actual-SQL browser create with reply lost after commit and same-key retry (one task), assignment denial, checklist/blocker/evidence gates, original date extension, terminal state/refresh, shared/created/assigned views,21-row page2 refresh, empty/denied recovery,320px/44px/Karla/no private browser storage/runtime errors. Captures inspected/shown; detector[]. Initial query syntax typo and shared-view browser assertion failure corrected/rerun, retained in P10 ledger/log/debug capture. No failure erased or external proof fabricated.

## External blockers / next smallest action

P02–P09 gates carried forward: Docker/Podman absent; .env.local/provider references unavailable; Google disabled; real Supabase17/Auth/PostgREST/official CLI types; school/external Google PKCE/consent/callback; old guest JWT revoke/renew/expiry/sponsor-loss; deployed token/body/parameter log redaction; true concurrent request/version/idempotency sessions; human UAT. Approved roster/FIN/MCD/sponsor/manager/gate-assessor authority, privacy custodian/basis/retention, HTTPS origin and logo remain open. No remote reset/provider change/service-role substitute.

After approved runtime/provider setup, verify loopback Supabase17, migrate/seed synthetic records, compare official types and run P10_A1–A3 through actual authenticated API subjects/concurrent connections; record human task/mobile/conflict acceptance. Contribution FK integration waits for its actual owning interface. Resume external verification with CONTINUE; P11 comments is separately code-eligible only.

## Preview / custody / usage

Live Vite5173 and **http://127.0.0.1:5178/tasks** retained/visible, labeled synthetic PostgreSQL/simulated sign-in; final workflow against current source/schema. Disposable5180 verifier closes. Obsolete owned synthetic P08/P09 servers5174/5176 stopped. No agents/chats/worktrees/dependencies, deployment, PR/main merge or messages/invitations.

Resumed clean at dd948ca705ca0683f09adbc118ce80da9d4c45cf on existing codex/core-build-checkpoints. User authorizes reviewed commit/push; final fetched local/remote commit/tree and clean worktree checked after this ledger and identity reported in chat.

Shared usage89% at reset1792834180, then natural rollover6 →17 →27% at reset1792852230. Original allowance1point; latest keep-going-until-finished instruction treated as overriding checkpoint-only stop, as announced. No fresh40point allocation, reset credit, purchase or wait. Cross-window/account-wide observations are not exact attribution. Scope stayed P10.
