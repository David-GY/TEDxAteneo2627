# Deliverable readiness and acceptance

P29 adds authoritative current-scope readiness. Task completion is a separate fact. The fixed categories are not_started, in_progress, blocked, ready_for_acceptance, accepted and cancelled. List/detail/Overview read the same private aggregation. Shared readers receive generic gate outcomes, never financial amounts, private titles, hidden record counts, case links, policy IDs or the scope fingerprint. Submitted evidence and scoped task exception choices require independent edit access; each exception task also requires its own access.

## Required checks

An active accountable core owner, outcome/criteria/target/lead unit, every required task, current accepted contribution agreement and completed contribution with an accepted current handoff receipt, required dependency completion, required handoffs, operational blocker resolution, current FIN/MCD approvals and configured external evidence all gate submission and acceptance. All related current noncancelled/unarchived typed financial/publicity cases must pass their actual private revision-bound authorization checks. FIN also rejects released budget authorization or unresolved actual-record review. Zero-cost financial work still requires FIN. External delivery evidence does not waive FIN's own external requirements.

Work types are fixed operations/cost/budget/expense/reimbursement/fundraising/sales/publicity/cost_publicity. The public declaration command only adds types; database latches preserve FIN/MCD requirements even after privileged type/label removal. Typed FIN/MCD linkage also latches the parent requirement. Cancelling a case cannot clear the requirement; a current valid replacement remains necessary. Existing records with no declared protected type and no typed linked case cannot be semantically classified from free text: real scope classification must be confirmed before activation.

## Authority and policy boundary

No actual acceptance policy is seeded. An immutable versioned per-deliverable policy pins an explicit current unit-scoped committee.manage assignment and its version, official reference, confirmer and validity dates. The acceptor must be independent of the owner and retain current core/workspace/unit authority. PM/head labels alone grant nothing; this bounded mapping requires an explicitly delegated unit role. Unsupported institutional acceptance or external-assessor structures must be mapped and verified before activation. Policy provisioning remains privileged/unexposed, subject to institutional confirmation; no browser self-configuration path exists.

A required external assessor is separately pinned by policy and independent of the owner. Verification binds an actual finalized parent-owned upload manifest/hash, current parent material/criteria, current authority stamp, reference, reason and finite future term-bounded expiry. It records the configured assessor's verification, not automatic proof of school approval or source rights.

## Submission, acceptance and reopening

read_deliverable_readiness returns permitted controls and current safe gates. submit_deliverable is owner-only; accept_deliverable requires the pinned independent current authority. Both recheck current gates, exact criteria revision, parent version and private scope fingerprint. The reviewer sees the submitted final evidence and must explicitly confirm the current criteria in the UI. The public legacy transition path rejects submit/accept/revise and cannot bypass these commands.

Immutable readiness events bind submission, acceptance and reopen history to the policy, criteria, fingerprint, actor and evidence. The fingerprint covers parent material/ownership/classification/deadlines/types, task versions/states, agreements, dependencies/predecessors, handoffs, exact FIN/MCD revisions and current validity, exceptions, external evidence and current acceptance authority stamps. Workflow-only transition/version changes do not invalidate their own receipt. Current acceptance additionally requires the original submitted evidence to match.

A governed scope/evidence/authority change invalidates current acceptance immediately in derived projections, preserving the historical acceptance event. Legacy pre-P29 acceptance without this binding requires re-review. The owner or configured reviewer explicitly reopens a submitted/accepted deliverable, then the owner resolves gates and resubmits; independent acceptance creates a new event. Restoration of a removed/recreated permission cannot resurrect the old accepted fingerprint. A submitted scope that changes must also reopen/resubmit before acceptance.

record_deliverable_scope_exception only excludes an exact current ordinary, noncontribution task version under the same lead unit, with independent parent/task management, current policy/criteria and an explicit reason. It cannot waive dependencies, contributions, handoffs, FIN, MCD or external requirements. Task/scope/policy changes invalidate it; history remains immutable. All linked tasks Done remains false when an exception covers an unfinished task.

## Transactions and verification limits

Commands derive the actor from the session, require expected versions and exact actor/key/payload retry, and atomically write state/history/audit/outbox. Current permission is checked before replay. READ COMMITTED term advisory serialization covers readiness input mutations, including budget entries and current authority. Broad term locking is conservative and can cause contention/deadlock rollback; independent provider sessions and performance remain unverified. Stale fingerprints conflict even when the parent version did not change.

The frontend reuses identity-bound in-memory decision memory. Conflicts retain inputs; uncertain responses freeze and recover the identical command/key without optimistic success. Malformed receipts remain uncertain. No local storage or real provider tokens are introduced.

Actual verification and failures: docs/build/steps/P29.md; source hashes: P29-domain.json and P29-browser.json. PGlite, synthetic subjects, fictional policies and isolated PNG bytes do not prove Supabase17/Auth/Storage/JWT, independent concurrent sessions, institutional authority/privacy or human/mobile/keyboard/assistive-technology acceptance. All STATE gates persist.
