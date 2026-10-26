# Resources and inclusive onboarding contract (P32)

Migration040 (`20261026221336_resources.sql`); migrations001–040,95tables/1018columns/131public functions. No production content, authority or contact assignments are seeded.

## Current interfaces

`read_resources(term, alias?)` returns currently permitted published guides/glossary, independently permitted links, scoped publisher drafts, own progress and creation options. `save_resource(term,id,values,expected_version,request_id)` appends an immutable draft/published revision. `set_onboarding_progress(term,item,revision,state,expected_version,request_id)` changes only the authenticated current core membership's checklist acknowledgment. All three derive the actor and enforce current term/capability; no actor argument, service-role substitute or raw-table API access. Generated types use the existing catalog generator.

Resources use a neutral restricted announcement/work audit spine, not a task/request or financial case. Four new forced-RLS/raw-denied tables hold resource scope/published pointer, immutable resource versions, permanent aliases and own progress. Existing command receipts provide exact actor/key/payload replay. Resource mutations serialize with the existing term lock under READ COMMITTED, enforce expected work version, and commit revision/alias/published pointer/redacted audit/outbox atomically. Generic work edits cannot change resource ownership/scope/content spine. Progress has no work/FIN/outbox creation; its version and exact command receipts retain mutation provenance without copying profile values.

## Content, ownership and publication

Guides/glossary have a stable UUID, term-scoped lowercase alias, label, plain text, active core owner, review date, optional actual service and typed related targets. Core publication requires current `admin.configure`; committee publication requires current unit `committee.manage`. Affiliation and course never participate. Existing scope/unit/kind/essential classification are fixed; a draft cannot silently widen an old resource. Owner/date/text/alias/targets can change in a new version. Core publication requires an explicit safe-content acknowledgment. This is no substitute for institutional content/privacy approval.

Published revisions are immutable and remain readable while later drafts are edited. Every saved alias is reserved permanently for the same UUID; old aliases resolve the current permitted publication. No resource label is a form field/option key. Existing versioned form IDs and schemas remain byte-for-byte logically unchanged by glossary rename. Review-due notices appear in the hub and publisher list; no reminder transport or schedule is created. MEA expansion stays unconfirmed until supplied.

## Independent scope and files

A guide does not grant access to its related work/resources, service directory or files. Typed targets are limited to current same-term task/deliverable/resource IDs, authorized for the publisher on save and separately for the reader on every projection. Lost target access removes the link and even the editing target reference. Drafts, aliases, titles, bodies and counts are filtered by current guide scope. There is no guest/core fallback and no anonymous resource read.

Raw URLs, file targets, copied file metadata, file byte previews and public Storage URLs are not supported. Text renders as text, without HTML/Markdown interpretation or automatic external fetches. A permitted work link opens the existing work page; its own file API/Edge/Storage checks remain authoritative. Current P06 organization contacts are looked up independently, with actual permitted mailto links and named missing-contact/backup states. Service links use the existing People page plus a stable process anchor. No personal contact/education field is required or copied into a guide.

## Onboarding and practice

The immutable baseline checklist is version1: confirm own profile, find contacts, locate work, understand FIN/MCD gates, confirm practice. Essential published core guidance has acknowledgments bound to its exact current published revision. The full hub computes completion from those own records; later publication requires a new acknowledgment. A filtered alias view does not claim overall completion. Completion is private self-attestation, never a role/capability, institutional approval or access prerequisite.

Essential text/navigation remains available during failed/empty reads or incomplete onboarding. Late joiners and members without assigned work receive the same guidance. Optional tour skip/revisit is supported; no completion ranking or affiliation comparison is stored. Guests receive static essential help, isolated practice and links to own contacts/explicitly shared work; persisted core checklist/directory/guides are intentionally unavailable to them.

The practice component accepts no production API, callback, file or record ID. Fictional title/date/scope create only a local rendered practice task/request, cleared on leaving. It explains ownership, proposed versus accepted dates, FIN including zero-cost plans and independent MCD review. Practice creates no real work item, request, FIN case, audit/outbox dispatch or upload. The separate checklist button records an acknowledgment only.

UI uses the incumbent Karla/tokens/44px/focus components. Current reads refresh on navigation, focus, visibility and30-second polling; pending/failed rechecks hide previous guidance and contacts. Publisher commands reuse identity-bound in-memory exact-retry handling; conflicts preserve fields. Old-scope editors disappear when their draft is no longer currently authorized. There is no browser persistence of guidance/practice contents.

## Verification limits

P32_A1–A3 pass in isolated PostgreSQL-shaped SQL and compiled Vite/browser tests, including no affiliation/course, actual scoped contact projection, rename/old aliases/form stability, draft isolation, target/unit revocation, raw/helper denial, safe text, no practice production work, exact retry/conflict, frozen writes and late rollback. This is synthetic PGlite18.6, not real Supabase17/Auth/PostgREST/Storage/JWT or independent concurrent-session proof. All inherited STATE gates remain. Approved institutional publishers/content/owners/contact backup, privacy basis/retention, deployed redaction, real current/old-token revocation/concurrency and human/mobile/keyboard/assistive-technology acceptance remain external.
