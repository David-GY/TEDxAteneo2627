# Personal overview contract

Migration018 exposes read_overview(term UUID), authenticated-only, session-derived active membership and exact detail access. Current sources: assigned tasks and owned deliverables, active term/unarchived records only. Terminal work is excluded. Blocked/submitted/proposed records enter the waiting lane; other eligible records enter actionable. Missing reviewer is explicitly unnamed. No approval/hand-off/inbox source or authority is invented.

OverviewRow is the extension boundary in src/features/overview/api.ts. Later sources must add their own authorized SQL projection into the same result, use source+UUID identity, and preserve independent access and deduplication. UI counts are filtered visible rows only. Maximum50 deterministically ordered records; hasMore is derived solely from eligible records, and the UI labels truncation. No hidden counts, private payload snippets or transitive parent access.

Owner/next person/action/absolute due date/committee/status/overdue and server refresh time are displayed. Explicit refresh, route return, focus and visible-tab return fetch again; subject/term changes discard the previous scope. No persistent browser cache or Realtime claim. Current provider/privacy/human blockers remain in STATE/P13; this contract enables no mutations or acceptance.

P15 accepted contributions appear once as canonical assigned tasks through this existing projection. Overview links to Contributions / assigned work; it exposes no pending head negotiations or additional parent access. P15 SQL/browser assertions verify canonical identity across these views.
