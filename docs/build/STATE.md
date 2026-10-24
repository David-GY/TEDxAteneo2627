# Current build state

Updated October 24, 2026 (Asia/Manila).

- Current resumable step: **P06 — in_progress**, directory/process contacts plus verified own core profile editor and separate audited commands. Resume **build-prompts/CONTINUE.md** for P06; do not advance to P07.
- Complete: P00/P01. P02–P05 remain **blocked_external**; their checkpoint ledgers remain authoritative. P07–P63 not executed.
- P06 still requires optional skills/pronunciation/affiliation disclosure, guest own/shared contacts and historical attribution integration. Own core editor and private-value/sharing commands are now delivered. This partial checkpoint does not claim P06 completion.
- Detail: docs/build/steps/P06.md, docs/people.md, docs/build/CONTRACTS.md. DESIGN.md remains visual authority.

## Delivered interfaces

13 public tables/161 columns/15 functions. P02 identity/P03 authority/P04 verified exact school roster/P05 invitations unchanged. P06 migration20261024000500_directory.sql adds read_people_directory and read_process_contacts: capability-gated read-only projections, no raw grant expansion. One person across current units/roles; exact school organization contact; course/year/phone/external contact independently null unless shared. Effective primary/backup contacts per active unit, missing assignments explicit. Guests receive no broad directory; their own/shared contact UI is pending.

/people uses real parallel RPCs and existing shell/components: name/unit/role search, plain process names, persistent help/task links, loading/empty/retry. /account now has a core-owner profile editor connected to separate audited value/sharing RPCs. P05 guest core/admin isolation, bearer scrubbing, zero-record sharing, current sponsor/expiry/revoke checks remain. No production fixture/preview bypass, real records or invented work IDs. Former current profiles excluded; historical work-record attribution remains pending.

## Actual verification / blockers

P06 SQL PASS three named assertions under authenticated subject fixtures, including an actual unit head capability. Frontend typecheck/lint/38 tests/build PASS. Catalog type generation/check PASS12/154/12. Browser verify-p06.cjs PASS labeled simulated gateway desktop/320px, one person/two units, missing backup, search/empty/help and zero runtime errors; captures inspected. Existing identity/authorization/google-auth/guests SQL regressions PASS, P05/P04 rerun on full P06. Evidence docs/build/evidence/P06-*; exact commands/failures in P06 ledger.

All P02–P05 external blockers carried forward: no Docker/Podman/Supabase PostgreSQL17 environment, real validated JWT/PostgREST, official CLI-type comparison, real school/external Google PKCE/consent/callback, old guest-JWT revoke/renew/expiry/sponsor-loss API checks, deployed token/body logging verification and human UAT. Prior .env.local/provider references unavailable and Google disabled; no provider setup changed. Local PGlite18.6/auth-shaped subjects and simulated UI do not replace these checks. No remote reset or service-role substitute.

Real roster, FIN/MCD authority, sponsor policy, privacy custodian/basis/retention, production HTTPS origin, approved logo and human UAT remain open.

## Preview / custody / usage

Existing dev http://127.0.0.1:5173/preview retained; Codex browser open requested (host queued). P06 actual UI shown through labeled browser-test fixture screenshots, no fixture endpoint ships. No public website/provider deployment/messages/invitations.

User authorized reviewed commits/pushes to existing public David-GY/TEDxAteneo2627 branch codex/core-build-checkpoints only. Start d3e74d757d980901ed064c3feb806e04fedf4922 verified against git ls-remote. Prior P05 snapshot8970e06 and tree4612298a9d93181b3f24ae1eaed4f939ae0ec656 retained. Current P06 commit and fetched remote-tree comparison are checked after this ledger is written and reported in final chat. No PR/main merge.

Shared five-hour usage80 →83 →84%, reset1792816155; starting allowance10 points, wind-down85, ceiling90. Partial checkpoint near wind-down before privacy mutation work. Account-wide observations, not exact attribution. No reset/credit purchase/wait, agents, extra chats/worktrees or dependency changes.

## Next smallest action

Resume **P06 using build-prompts/CONTINUE.md**: finish optional skills/pronunciation/affiliation disclosure, guest own/shared contacts without invented P07 scope, and historical-attribution boundary. The own core editor/value and visibility commands now exist. Then run security/UI checks. After approved local container/provider setup, verify loopback target and rerun P02–P06 on real Supabase17/JWT/Google before live activation. Do not erase older blockers.

Final custody: P06 snapshot3c18874 pushed/fetched; local/remote tree3fa4f7bbb1dce466cfd00ba6963ba5584384b5c8 matched exactly. Final shared usage87% (same window; below90% ceiling). This documentation-only custody update is also backed up and verified before finish.


Latest continuation: migration20261024000600_own_profile_read.sql adds authenticated core-owner read_own_profile, deriving identity from session/current membership, returning private values/sharing/version without directory capability; no writes. P06 SQL extended and PASS (head/self, missing profile, wrong term, guest/suspension denial), type generation/check12/154/13, typecheck/lint/build PASS. Existing frontend/browser checks not rerun for this backend-only change. Preview5173 retained. Shared baseline87 →88%, reset1792816155, effective allowance3 points; small verified checkpoint per contract. All P02–P05 blockers and unfinished P06 scope above persist. This continuation commit is pushed/fetched and remote tree verified before finish.


Latest continuation supersedes earlier read-only notes: migration007 adds profile_commands with forcedRLS/no-direct-grants and separate owner-only version/idempotency/audited save_private_profile/set_profile_visibility; raw private-profile client writes revoked. Own core editor now connected at /account. Current types13/161/15. SQL/P04/P05 regressions, typecheck/lint/build,40frontend tests plus3 additional gateway tests and account/directory mobile browser checks PASS; exact run boundaries/failures in P06 ledger. Usage93 →96 →97 →99%, reset1792816155; user explicitly overrode headroom, no reset/credit purchase. Next remains unfinished P06 optional skills/affiliation disclosure, guest contacts/historical attribution; all P02–P05 external blockers retained. Preview restarted5173/session68785; labeled fixture screenshots shown. Checkpoint pushed/fetched and exact tree checked before finish.
