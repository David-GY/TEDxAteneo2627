# Permission-filtered search (P43)

Source053 extends source052. Local catalog:53migrations,121tables,1198columns,163public functions. Hosted source001–043 remains unchanged. This is local review-ready implementation, not provider or human acceptance.

`search_workspace(term,query,filters,cursor)` derives the actor from the current authenticated core membership with workspace.read. It accepts a2–120character query, a closed kind filter (`all`, `task`, `deliverable`, `request`, `guide`, `glossary`, `contact`) and a query/actor/term/category-bound keyset cursor. Unknown fields, malformed cursor values and control characters reject. Pages contain at most20rows; the ordering key is kind plus UUID. Cursors select a range, never grant authority. Current authorization repeats on every call.

Only these sources participate:

| Source | Authorization and searchable projection |
| --- | --- |
| Task/deliverable | Current can_access_work(detail), unarchived record; title, issued reference, exact UUID. No body, summary, finance payload or file extraction. |
| Request | Current requester-only request_readable predicate and unarchived record; operational title, issued tracking reference, exact UUID. No draft/submitted payload, amount, evidence or desk bypass. |
| Guide/glossary | Current resource_visible and current published revision; approved label/body and aliases that appeared in published history. A reserved private-draft alias alone is insufficient. No draft text or copied linked-target contents. |
| Directory contact | Current read_directory predicate; organizational display name and current unit deployment for old-unit alias matching. No email, optional/private profile, phone, affiliation or external-contact field, even if separately shared in People. |

Indexed title/text candidates are authorized before response projection and counts. The response contains only title, kind, optional issued reference, term ID/label, canonical internal link and an exact matched old-unit alias. It contains no body snippet, hidden count or redaction placeholder. Private and nonexistent matches are indistinguishable; independently permitted fuzzy matches can still appear. Finance/evaluation/private-profile/file stores and P42 announcements are excluded. There is no external AI/index service or arbitrary query execution.

Permanent P33 aliases resolve the same term/unit identity, including an ordinary work origin where retained. Unit merge links never participate in authorization or search expansion. Reserved reference-shaped queries do not traverse unit aliases. Existing issued prefixes remain intact; a legacy request prefix may equal TASK/DEL, so kind plus reference plus term disambiguates rather than renumbering an item. Closed category filters resolve such collisions explicitly.

`read_search_terms(current_term)` lists only same-organization terms in which the caller currently has core membership and workspace.read. `read_search_term_context(selected_term)` derives that term's own context and capabilities, with no actor or role argument. The ordinary verified identity/bootstrap path runs first in the production gateway; contexts are never merged. Core reads repeat current authorization. A verified guest's existing own-term shared-work link keeps its guest context, while global search and other terms remain closed.

The member selects one term at a time. Selection clears old query/results; each title and Copy link carries its canonical UUID plus selected term. Destination loaders recheck that exact term. The sign-in return sanitizer keeps only allowed term/record IDs, preventing fallback to a different term or forwarding arbitrary query fields. The ordinary navigation returns to its current default term unless its link explicitly carries a term.

Search uses300ms typeahead, native form submit, categorized title links, Clear, scoped retry/error states and safe clipboard failure. Query text is not written to URLs or browser storage. Input/category/scope changes and unmount invalidate late responses; focus hides old rows. Offered terms are hidden during focus/visibility/poll rechecks, with late term-list responses rejected. Results are plain text. Search controls and title targets use the44px house target; actual newcomer/native zoom/assistive checks remain open.

Source053 installs pg_trgm and unaccent in the extensions schema, with a private fixed-dictionary normalization helper and partial GIN full-text/trigram indexes over operational work titles and published guide text. The source052 narrower title index is replaced. A preexisting extension in another schema fails the entire transaction with search_extension_schema_unavailable; migration does not move provider extensions automatically. A future dictionary change requires rebuilding dependent indexes. Do not deploy without provider extension/schema and index-build timing rehearsal.

Local3,000-record measurements and normal-planner candidate EXPLAIN results are in build/evidence/P43-search-scale.json. They are not hosted latency/concurrency guarantees. Index maintenance affects planner choice; the scale fixture performs VACUUM/ANALYZE before measuring. Provider17/JWT/current-old-token/independent-session races, actual institutional/privacy/retention inputs, newcomer task observations, native zoom/assistive technology and restore gates remain open. Earlier P35/P36/P39/P41/P42 remain incomplete.

Implementation references checked: [PostgreSQL17 pg_trgm](https://www.postgresql.org/docs/17/pgtrgm.html), [unaccent](https://www.postgresql.org/docs/17/unaccent.html), and [Supabase17.11 compatibility notice](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes). No custom operators are created by this migration; provider rehearsal remains necessary.
