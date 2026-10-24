# Current build state

Updated October24,2026 (Asia/Manila).

- Active step: **P10 — in_progress (partial)**. Read-only owned-task foundation delivered. create_task/update_task/assign_task/transition_task, task detail/editor, assignee/collaborators/checklist/blocked/progress and cross-unit assignment gates remain pending.
- **Resume build-prompts/CONTINUE.md for P10. Do not advance to P11.** Next smallest action: fixed task fields and authoritative command permissions, named P10_A1–A3 regressions, then editor/assignment controls.
- P00/P01 complete; P02–P09 blocked_external with their exact ledgers preserved. P11–P63 not executed. P10_A1–A3 remain pending; the new P10_R0 read/date assertion is not full task acceptance.
- Detailed current checkpoint: docs/build/steps/P10.md; contracts docs/build/CONTRACTS.md and prior deliverables/work/permissions/guest/profile docs. DESIGN.md remains visual authority.

## Delivered / verified

Schema28tables/341columns/32public functions, migrations001–013. New authenticated actor-derived read_owned_tasks reads existing own canonical task summaries, authorized rows/counts and deterministic pagination20. No private task body/parent data; server Manila date-only overdue cutoff. Actual /tasks SDK adapter and read-only page with honest loading/error/recovery/empty states. It identifies owned records, not assigned work or a completed authoring workflow. No new business mutation or assignment authorization.

PASS pnpm test:tasks P10_R0 (owned-only/count/body isolation, page2 and today/yesterday Manila boundary); PostgreSQL18.6/PGlite/auth-shaped subjects only. PASS frontend16files/66tests; typecheck/lint/build (165modules, app388.22kB/gzip118.91kB, CSS11.55kB/gzip3.06kB); generated/drift-check types28/341/32. Browser actual SQL row/archive-reload-empty, desktop/320px/no overflow/runtime errors/private storage; captures inspected/shown, detector[]. P10_A1/A2/A3 command/assignment/assignee progress checks unimplemented, not passed. Prior step checks are retained historical evidence, not claimed rerun on migration013.

P09 scoped deliverable proposal/create/edit/reassignment/lifecycle/criteria/evidence/idempotency/audit/outbox remain. Accepted workflow does not imply release/finance/publicity readiness; unresolved governed gates fail closed until authoritative later interfaces. P08 permitted rows/counts/filter/deep links and P02–P07 identity/grant/privacy invariants remain. No real records or production fixture endpoint.

## External blockers retained

P02–P09: Docker/Podman absent; .env.local/provider references unavailable; Google disabled; real Supabase17/Auth/PostgREST and official CLI types; school/external Google PKCE/consent/callback; old guest JWT revoke/renew/expiry/sponsor-loss; deployed token/body/parameter log redaction; actual concurrent request/version/idempotency sessions; human UAT. Approved roster/FIN/MCD/sponsor/manager/gate-assessor authority, privacy custodian/basis/retention, HTTPS origin and approved logo remain open. No remote reset/provider change/service-role substitute. Detailed older ledgers remain authoritative for their specific gates.

## Preview / budget / custody

Live http://127.0.0.1:5178/tasks visibly open/retained, labeled local synthetic PostgreSQL/simulated sign-in and explicitly read-only; owned synthetic draft uses existing P07 command. Disposable browser database5179 closes after checks. Existing Vite5173/P08/P09 previews retained. No agents/chats/worktrees/dependencies, deployment, PR/main merge or messages/invitations.

Shared usage84 →87%, reset1792834180; effective allowance6points, wind-down85used, ceiling90used. BUILD-CONTRACT requires the smallest verifiable checkpoint below10points. No complex task mutation migration opened, reset/purchase/wait or fresh allocation. Shared observations, not exact attribution.

User authorizes reviewed checkpoint commit/push to existing codex/core-build-checkpoints on David-GY/TEDxAteneo2627. Started clean at44e623c0a0f95997a82524dc8bd5d58b4bcaca4b; final pushed/fetched commit/tree and clean worktree verified after this ledger, identity reported in chat. Backup does not mark P10 complete.
