# TEDx build execution contract

Owner latest instruction October30: hold off on deployment. This retracts the earlier always-deploy request. Keep live schedules and external messages disabled. Local preview and authorized reviewed Git commits/pushes may continue; deployment requires a later explicit instruction and an identified target.

This contract applies to every numbered prompt in this pack. The prompt prepares one bounded implementation session; it does not authorize running later prompts automatically.

## Start with the right context

Workspace: `C:/Users/david/OneDrive/Documents/ChatGPT/TEDx`.
Specification: `TEDx-Core-Dashboard-Implementation-Plan.md` in the workspace root.
Read repository instructions and use skill-router. Read `docs/build/STATE.md`, the selected step's checkpoint if present, and only the specification sections/feature IDs named in that prompt. Locate sections by heading rather than loading the entire 16,000-word specification on every run. Read relevant code and existing contracts. Step P00 creates the initial state files.

Implement the selected step, including required integrations and tests. Do not stop after describing an approach. Preserve unrelated work. Reuse the current suitable checkout and existing tooling; create no extra chats, agents, automations, or worktrees without the authorization required by project instructions. Do not replan the whole application, redesign it, or implement later steps.

Dependencies name required code/interfaces, not an excuse to abandon independent local work. A prerequisite with passing local implementation but a pending provider/human check can support further local implementation if that missing check is not needed by the current step. Carry its exact blocker forward; never relabel it complete. Provider verification, actual privacy/authority decisions, human UAT, and restore evidence still block the relevant live activation/release gate. Repair a missing required interface before proceeding, within this step's budget, and record that scope change.

## Model and usage budget

The numbered file states its recommended model and effort. The human selects these in the model/effort picker before sending it; prompt text does not switch the active model. Default is GPT-6.1 Sol (`gpt-6.1-sol`), with Low, Medium, or High effort as listed. P63 recommends GPT-6 Astra (`gpt-6-astra`) High for a final audit; Sol 6.1 High is the fallback. Keep the existing execution speed; no automatic Fast/Ultrafast, Max/Ultra, or subagents. These recommendations are judgments about risk and scope, not measured task benchmarks.

40% means **40 percentage points of the total five-hour usage window**, not 40% of whatever remains and not two hours of runtime. No prompt can guarantee a consumption percentage. Context, model, reasoning, tools, debugging, shared account activity, and resets affect the reading. Finish early when the scope is done; never spend allowance to fill a target.

When the first-party usage-limit tool is available, read the current five-hour usedPercent and reset timestamp at session start. Effective soft budget is `min(40, max(0, 100 - startingUsedPercent - 10))` percentage points, keeping 10 points of account headroom. Check after the first coherent implementation/test batch and near completion, not after every tool call. Start winding down five points before that effective budget. If a step grows, finish the current safe transaction/edit, record real verification and remaining work, then stop at a checkpoint. Never intentionally run beyond 40 points to finish a large feature. This is best-effort: a single operation or other chat can overshoot between observations.

Record readings as shared-account observations, not exact attribution to this prompt. If the window resets or counters become unavailable, report uncertainty and retain the original scope; do not restart a fresh 40-point allocation. Without a usage tool, use small work batches and explicit resumable boundaries; do not invent a percentage or a token-to-quota conversion. Do not wait for a reset, buy credits, consume a reset credit, or run continuously for two hours. With less than 10 points effective budget, prefer the smallest verifiable checkpoint rather than opening a complex migration.

## Product and authority constraints

- Use React, TypeScript, Vite, Supabase, and the planned Cloudflare static deployment unless actual repository facts require a documented adjustment. Preserve existing package manager/versions once established.
- Keep Karla, calm neutral layout, interface accent `#b82320`, visible accessible focus, and 44-pixel controls. Use a supplied approved TEDx logo; do not fabricate licensed identity. Logo token `#EB0028` is separate from the interface accent. No decorative redesign.
- Event date: April 17, 2027; timezone: Asia/Manila. Budget: ₱0. No silent paid dependency.
- Primary experience: core deliverables, committee synergies, cross-committee tasks, named ownership, explicit acceptance, next actions.
- Exact school domain `student.ateneo.edu` plus approved roster. Guests require explicit verified-email scope/expiry. MEAn status never grants privilege; deployments do.
- FIN is required for costs and fundraising/sales, including zero-cost financial plans. MCD reviews finalized publicity. Independent authority, version-bound evidence, no self-approval, no direct client status bypass.
- Admin configurability uses stable IDs, versioned published definitions, scoped permissions, and fixed security invariants. No arbitrary user-supplied SQL/scripts or implicit access expansion from unit merges.
- Enable database/file RLS before exposed reads. Sensitive contents stay separate; no service keys in clients. Check authorization for joins, snippets, counts, exports, and every file link.
- Store PHP money in integer centavos with explicit quantity/rounding rules; preserve original deadlines. Audit meaningful changes with no raw sensitive payloads in logs.
- Use only synthetic local/staging data unless the user has supplied authorized real records and the relevant privacy gate has passed. Unknown committee structure, approver authority, retention, and school API permissions remain explicit open inputs. Do not invent them to finish a screen.

## Consistent interfaces and files

### Newcomer adoption requirement

Follow [docs/newcomer-experience.md](../docs/newcomer-experience.md) for existing-screen remediation and every remaining step through P63. Review the mapped open findings in [docs/build/ADOPTION-AUDIT.md](../docs/build/ADOPTION-AUDIT.md) when touching those flows. Keep ordinary work focused on a named next action, owner/date and help; plain-language labels, stable concise display references, safe edit/retry recovery, contextual required fields and progressive disclosure. Preserve all approval/privacy/access/history invariants. Internal UUIDs/hashes/capability keys must not be required knowledge for ordinary members; do not silently renumber existing references or truncate UUIDs into collision-prone IDs.

For each UI change record the affected role/journey and empty/error/conflict/mobile/keyboard behavior in its checkpoint. No automatic adoption pass from feature completion or automation. P50/P63 must record actual representative newcomer task success, time, wrong turns and assistance against the original section14 targets, plus current adoption findings resolved/deferred with impact. Optional P51–P61 remain separately selected/gated and add no everyday navigation/setup burden while disabled. This adds acceptance discipline, not authorization for unrelated implementation or a wholesale redesign.

Paths in numbered prompts are proposed ownership boundaries. If earlier implementation established an equivalent path, use it and record the mapping; do not create duplicate modules to match a filename. P00 establishes scripts and `docs/build/CONTRACTS.md`; every later step updates only contracts it owns.

Database business commands are snake_case RPCs deriving actor identity from the authenticated session, never caller-supplied actor IDs. Mutations that need retry/concurrency safety accept expected version and idempotency key. Record structured validation/permission/conflict errors, immutable revisions/decisions, and transactional audit/outbox where relevant. Generate Supabase types after schema changes. No code can merely claim success for an unimplemented RPC.

Use the project's working typecheck/lint/build commands and targeted unit/database/browser tests. Add named, meaningful assertions for money, security, state transitions, concurrency, and data loss. Do not add tests merely to mirror static styling. Never report a test as passed if not run. If Docker, credentials, or provider access are missing, finish independent code and local checks, document the exact prerequisite, and mark the affected verification blocked. Fixtures never masquerade as a connected backend.

Local migrations and synthetic resets are allowed after verifying the local target. Never reset, drop, seed, purge, or run a destructive migration against a remote project by assumption. External deployment/configuration is authorized only by a step that names it and an identified target with passed gates. Do not send messages/invitations, change institutional policies, create paid resources, or publish publicly as a side effect. Do not commit or push unless separately authorized. Ask only for genuinely missing inputs; routine local implementation needs no new approval.

## Mandatory checkpoint and finish

Maintain `docs/build/STATE.md` as a concise current state: active step, completed steps, partial/blocked steps, connected environments, schema/contracts, exact next action, and outstanding human/provider inputs. Keep older detail in `docs/build/steps/PXX.md`.

The selected checkpoint records: delivered behavior; files/migrations changed; exact commands/results; acceptance items passed/failed/unverified; provider setup still needed; usage observations if available; and the next smallest action. Status is one of `not_started`, `in_progress`, `blocked_external`, `ready_for_review`, or `complete`. Complete requires all step acceptance checks; partial code is not completion. Never erase a failed check from the ledger because a later prompt is available.

If budget ends mid-step, resume the same ID with `build-prompts/CONTINUE.md`. Do not skip to its successor. If finished, end with a short description, checks, material limitation, and the next eligible prompt ID. Leave all changes reviewable. No need to repeat the entire plan in chat.
