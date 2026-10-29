# P07 work-record and command contract

P36-R1 local extension: [task/deliverable references](work-references.md) adds immutable server-issued TASK/DEL numbers in separate raw-denied tables and authorized read/copy metadata. UUIDs, existing command receipts/work versions and request tracking remain unchanged. Source045 is not hosted.

Local implementation delivered; real Supabase17/JWT/parallel-session checks remain blocked. Scope is common **draft** records and access infrastructure, not deliverable acceptance, request submission, approval, publishing or notification delivery.

## Storage and integrity

Migration20261024001000_work_items.sql adds work_items, record_grants, status_definitions, audit_events, idempotency_keys and outbox_jobs plus fixed deliverables/tasks/requests/announcements children. Every work row has exactly one matching child at transaction end; composite organization/term/kind FKs and deferred constraint triggers enforce this. Child identities cannot move. Draft body is bounded text, not an EAV/JSON authority platform. Later feature migrations extend these fixed children with typed business fields; they must create parent and child in one transaction.

Editable parent, child, grant, status and outbox rows have server actor/time/version stamps. work_items.version is the expected version for all public work mutations; child version stamps track local body edits and are not a second client concurrency token. Original deadline fields and organization/term/kind/classification/parent links are immutable in this slice. Dates stay date-only; interpret date deadlines under the plan's23:59 Manila convention in future deadline features. The current creator sets no deadlines. Owner display name is captured on the work row and actor display name on audit, preserving attribution without private-profile joins.

status_definitions has per-term/kind stable keys and immutable semantic category/resource kind. The creator uses only the canonical draft semantic; a misleading status label cannot authorize approval. No status/owner/approval mutation RPC exists in P07. Direct client INSERT/UPDATE/DELETE is denied across all spine tables. No policy, service key or generic command allows a client to bypass that boundary.

role_assignments now has a same-term work_id FK and scope=work, paired with role_permissions allowed_scope=work only for workspace.read/committee.manage. has_work_capability evaluates this exact record. Existing has_capability/explain_access never turn work grants into term/unit privileges. Existing unit membership and role dates/revocation remain authoritative.

record_grants has exactly one target: same-term core member_id, same-term unit_id, or same-term guest_invitation_id (real P05 FK). Kind read/edit, bounded active interval, grantor membership, optional revocation and server version. Grant creation requires the named work owner, effective target and an active draft. Guests are read-only and require the current owner's own valid sponsored invitation; no approval/guest-field editing is invented. Member/unit grants are exact, not inherited through work parents. Record withdrawal is permitted for an otherwise authorized owner even on frozen/submitted work; content/grant additions remain closed.

## Read contract

Ordinary core summaries require current workspace.read; owner/explicit participants can read their exact restricted item. Summary columns include safe title/summary, kind/classification, named owner snapshot, unit/status/deadline and server stamps. parent_work_item_id is **not** a client-readable column, so do not SELECT*. Child bodies and audit require detail access. Grants expose only the owner's view or the currently matching principal's row. Anonymous callers get no table/helper access. The private RLS helpers use a trusted definer and fixed empty search_path, avoiding recursive raw policies.

- can_access_work(work_id,summary/detail/edit/owner): current-subject record permission, not proof of draft transition eligibility. Commands additionally enforce term/state/version/field rules. Unknown/inaccessible IDs and invalid levels return false.
- has_work_capability(work_id,capability): exact current work-role grant only, never a parent/unit/term expansion.
- can_read_work_grant(grant_id): exact authorized grant-row predicate.
- read_work_parent(work_id): safe parent summary only if child details **and** parent summary are independently allowed; otherwise null. No transitive ancestor/sibling lookup.

Guest reads recheck the exact redeemed invitation's email, sponsor, expiry/revocation and grant, including unchanged authenticated subjects. Sponsor list counts only active attached work visible to that sponsor. New invitations/renewals still start with zero records; no automatic copy of old grants. Redemption reports its actual attached record count. read_guest_contacts returns only current active owner names and exact-school organization routes from explicitly granted work; personal phone/course/profile fields stay absent. scopeMode is awaiting_record_attachment or explicit_records, derived from live grants rather than the legacy creation marker. Withdrawal removes related contacts on the next read. Guest own details stay private to the guest. No broad directory fallback.

## Public work commands

All accept caller-generated request UUIDs; identity/owner/actor come from current verified membership. Null defaultable fields only make nullable SDK inputs possible; request/version requirements are checked server-side.

| RPC | Inputs beyond identity-derived state | Result |
| --- | --- | --- |
| create_work_item | term, fixed kind, title, safe_summary, body, ordinary/restricted classification, optional deployed lead unit, optional editable parent with expected parent version, request_id | workItemId, kind, version1; parent+correct child+owner grant+audit+outbox+retry result atomically |
| update_work_item | work ID, title/summary/body, expected work version, request_id | workItemId/version; draft only, no owner/status/classification/approval bypass |
| grant_work_access | work ID, exactly one member/unit/invitation principal, read/edit, absolute expiry, expected work version, request_id | workItemId/grantId/version; increments work version for access change |
| revoke_work_access | grant ID, expected work version, request_id | workItemId/grantId/version; grant revoked, no content rewrite |

Current effective membership, unit dates, owner/record permission, target and active term are enforced. No cross-unit assignments to arbitrary people: creation names the caller as owner; lead unit must be the caller's current deployment. P07 drafts are not published commitments. Later governed commands must repeat their own FIN/MCD/independent-approver conditions.

Idempotency is unique actor/command/client_key. A transaction advisory lock serializes identical first keys; a work-row lock guards each expected version. Canonical bounded payload hashing includes expected version; grant expiry is normalized to UTC so session timezone cannot change retry identity. Identical retries return the exact prior receipt even if later edits advanced the row. Reused key/different payload fails22023. Current authorization is checked before cached results; a revoked/suspended actor cannot recover a receipt. No automatic retry or key rotation in the client adapter.

Accepted changes write immutable audit metadata with changed field names, not titles/body/personal values. Pending outbox payload contains event/work IDs and version only; no recipient or sensitive payload. Same transaction writes business rows, idempotency result, audit and outbox; failure rolls all back. No worker, email, webhook or notification is dispatched here. Future delivery must recheck current access. Idempotency expiry stays null/no automatic purge until approved retention, avoiding an invented retry reuse horizon.

## Client and errors

src/lib/commands.ts exports createWorkCommands with four named typed methods and discriminated CommandResult, not a generic entity dispatcher. Create requires a request key; all existing-record mutations require expected work version. A typed principal union prevents multiple targets. Receipts are runtime-validated and never fabricated for missing setup, network failure or malformed data. Error mapping keeps only whitelisted categories/messages, never raw SQL details or protected metadata.

42501/auth failure→permission_denied;22023/input/FK/check failure→validation_failed; command_idempotency_conflict→idempotency_conflict;40001→stale_version;55000→dependency_blocked; known missing-approver/quota guards map separately; uniqueness/lock conflict→conflict; transport/unconfigured→unavailable; unrecognized server response→unexpected. Callers must reload conflicts and explicitly retry unconfirmed requests with the same key/details. The adapter performs no hidden retry or optimistic success.

## Verification boundary

pnpm test:work-access runs named P07_A1–A3 under isolated in-memory PGlite18.6 and authenticated-shaped subjects. It proves the local stale-version logic with two actors observing the same version, not actual simultaneous PostgreSQL17 sessions. Browser fixtures are fictional/test-only and demonstrate scoped contact presentation, not real provider transport. Official types, JWT/PostgREST/parallel locks, real Google callbacks, deployed logging, privacy/authority decisions and human UAT remain gated by P02–P06 prerequisites. No remote reset, provider configuration, real data, publication or messaging is authorized by these results.
