# P11 comments and evidence contract

Local implementation delivered. Actual Supabase17/JWT, concurrent sessions, authority/privacy and human verification remain blocked. No external messages or notification delivery.

## Storage and access

Migration016_comments.sql adds comments, comment_revisions and comment_evidence. RLS is enabled/forced before SELECT grants; authenticated clients have no direct write grants. Author/name/time are captured server-side. Revisions and evidence are append-only. Comments have their own expected version; additive creation does not overwrite/increment the work version. Parent locks coordinate writes with evidence capture. Audit stores current parent version and changed field names, never comment text or mention names.

Threads, history, direct-table policies and candidate queries independently check current exact work detail access. Ordinary deliverable summary access is insufficient; no parent/sibling expansion. Core participants/scoped managers with current detail access may comment on active, unarchived task/deliverable records. Expired/suspended subjects fail. Existing guests can read explicitly shared published history only; writing and mention enumeration remain closed under the existing read-only guest contract. Frozen/archived work is read-only.

Drafts and removed-draft heads are author-only. Publication shares the published revision, never earlier private draft bodies/reasons with other participants. Authors amend own comments. Published comments cannot be removed. Own unreferenced draft removal appends a tombstone. Authors or current work owner may append a reasoned redaction of published text. Redaction hides all bodies from ordinary RPC/table reads, including the author; immutable originals and evidence FKs remain in custody. No app purge or retention-policy decision is introduced.

## RPCs and client

| RPC | Inputs | Result |
| --- | --- | --- |
| add_comment | work ID, body, mention UUID array, draft boolean, request UUID | commentId/version1 |
| revise_comment | comment ID, body, mention UUID array, edit/publish/remove/redact action, reason, expected comment version, request UUID | commentId/version |
| read_comments | work ID, page default1 | nullable thread: items/total/page/canComment |
| read_comment_history | comment ID | filtered immutable revisions, or empty |
| mention_candidates | work ID, literal name search default empty | up to20 eligible id/name pairs, or empty |
| can_read_comment | comment ID | current-subject policy predicate |

Plain text only, bounded8000 characters; reason1–2000; at most20 mentions;20 comments/page, deterministic created_at/id ordering, page1–10000. No Markdown/HTML parsing or linkification. UI displays database author/time/version, permissions, amendments/reasons, evidence notices and history. Times are Asia/Manila; candidate lookup has loading/error/empty states with no directory fallback. Record/subject changes discard the old thread scope; no browser draft storage.

Commands derive actor from session and reuse existing exact actor/command/key/payload receipts and transaction locks. Changed-key payloads and stale versions fail. Stale editors retain text and their original version. Unconfirmed writes freeze inputs and retry the same key/payload. Explicit reload/navigation/editor closure may discard local unsaved text; conflicts explain copying before reopening the latest version. Saving another comment preserves an unsaved new comment in the same thread.

Candidates are active same-term owners, current task collaborators with required deployment, or exact active member/unit-grant participants. Directory/summary visibility alone never qualifies. Guests and broad directory/manager enumeration are excluded; managers qualify when also explicitly participating. Eligibility is rechecked on each new write. Revision metadata retains selected IDs. Published mention commands create one deduplicated comment_mentions outbox event containing opaque event/work/comment IDs and revision only. Drafts emit no mention event; generic redacted audit/outbox behavior remains. A future worker must recheck sender/recipient/work/revision/redaction eligibility. No worker/provider is enabled.

## Immutable evidence

Paste the exact token `comment:UUID:revision` into existing task completion/review or deliverable submission/review evidence. Immutable task_revisions/deliverable_revisions INSERT triggers validate same-work/current-access/published-revision and pin through real composite FKs in comment_evidence. References never grant access. Invalid, draft, removed, redacted, cross-work or missing references fail closed. A redacted token cannot support a new submission. Other unstructured evidence remains an unverified note.

Edits never change pinned originals. The thread identifies original task/submission/decision revision and any later amendment. P11_A3 uses the existing trusted historical decision-bearing deliverable revision in a synthetic fixture; no later governed decision API is invented/enabled. Browser checks pin through actual task transition RPC. FIN/MCD/deliverable acceptance remains independent.

## Mapping

src/features/comments/api.ts and Comments.tsx are shared by existing TaskDetail.tsx and DeliverablePage.tsx through AuthGateway/router and actual SDK. scripts/preview-p08.cjs remains the common isolated SQL host; preview-p11.cjs starts5178. test-comments.cjs/comments.test.sql own named SQL checks; comments.test.tsx owns rendering/conflict/retry checks; verify-p11.cjs owns actual-SQL browser checks on disposable5181. Generated catalog:33tables/392columns/45public functions. Official CLI comparison remains blocked. Evidence/limitations: docs/build/steps/P11.md.
