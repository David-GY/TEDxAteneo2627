# People, profiles and contact boundaries — P06

P06 local implementation is delivered. Status remains **blocked_external** until real Supabase/Google and human checks pass. See docs/build/steps/P06.md for the full acceptance ledger and prior partial checkpoints.

## Core directory and processes

`read_people_directory(p_term_id)` returns one JSON row per permitted current core member: id, name, exact-school organization contact, current units/roles, and separately consent-filtered course/year/phone/externalContact/skills/pronunciation/affiliation. Unshared values are null even for heads. Search uses already-permitted name/unit/role fields, never hidden private values. Access delegates to P03/P04 current verified identity/membership/capability checks. Archived/suspended/former current profiles are excluded.

`read_process_contacts(p_term_id)` returns active unit names and effective primary/backup deployment identities from that same permitted directory. Missing contacts stay explicit; no fabricated backup or official roster is introduced. Multiple units do not duplicate a person. Plain unit names are shown instead of requiring unit codes. Approved assignments/names still require the real roster.

## Own core profile

`read_own_profile(p_term_id)` derives owner from current core membership, takes no member-ID argument, and returns private values/sharing flags/profile version without needing directory capability. Missing profile version is0 and sharing defaults false; denied access returns null.

`save_private_profile(p_term_id,p_values,p_expected_version,p_request_id)` accepts only optional course/yearLevel/phone/externalContact/skills/pronunciation/affiliation string or null values. Limits:200/80/80/320/1000/200/80 characters. Whitespace-only values become null. Affiliation uses the existing term_memberships.affiliation_tag source; it is descriptive and never grants privilege. Direct authenticated affiliation updates are revoked.

`set_profile_visibility` accepts p_visibility instead of p_values and only boolean shareCourse/shareYearLevel/sharePhone/shareExternalContact/shareSkills/sharePronunciation/shareAffiliation. The commands are distinct, so saving values cannot silently alter disclosure. Both derive actor, lock the member across terms, recheck current active-term authority, validate whitelist/types, check version and persist request fingerprints/redacted audit transactionally. First profile save expects0; delayed retries return current state without restoring old values/consent. Changed retry payload22023, stale version40001, denied/frozen42501. Direct authenticated private-profile inserts/updates are revoked, including column grants. No raw values are written to profile_commands; new events capture actor_display_name for historical attribution without an old private-profile lookup. Earlier events retain a null name rather than inventing history. No new public historical-member lookup is exposed.

/account uses the existing UI system with separate value/sharing forms, clear optional fields/MEAn explanation, retained retry IDs after uncertain responses, conflict recovery and explicit reload/discard. Nothing is required for ordinary help/work links. No private values enter browser storage. A member changing a currently shared value is told it updates the directory. Frozen-term profile changes are denied under the incumbent term rule.

## Guest contacts

`read_guest_contacts(p_term_id)` derives current verified guest identity and rechecks the redeemed invitation, email, term, expiry/revocation and current sponsor authority. It returns only own displayName/verifiedEmail/contactRoute/version, sharedContacts:[] and scopeMode:awaiting_record_attachment. Denied reads return null. Guests never receive the core directory, member counts, private profiles or sponsor private contact information.

`save_guest_contact_profile(p_term_id,p_values,p_expected_version,p_request_id)` accepts only optional displayName/contactRoute strings/null (200/320 characters). It derives user, serializes first inserts/retries on that auth user, rechecks invitation access, validates fields/version and writes redacted guest_profile_commands in the same transaction. It cannot change verified email/identity or share details. Guest tables force RLS with no direct API grants. Expiry, sponsor loss and revocation deny unchanged-subject reads/writes, including retries. Guest /account explicitly shows own details and an empty shared-contact list; no core profile controls or directory links.

The empty shared list follows P05's actual zero-record scope. P07 must supply real record FKs/authorization before contact attachment; no dangling work IDs, implicit sponsor sharing or full-directory fallback is added here. Future authorized record views must carry their own retained attribution label, following the captured-name boundary demonstrated by P06 events; no new P07 work records exist in P06.

## Verification and provider gates

Migrations005–009, SQL tests directory.test.sql/guest_contacts.test.sql, account/people frontend tests and verify-p06.cjs cover the current boundaries. Types:15 tables/181 columns/17 public functions. Test-only fictional browser interception is explicitly labeled and never ships as a fixture endpoint.

PGlite18.6/auth-shaped subjects and simulated UI are local evidence only. Supabase17/Docker, official types, real Google/validated JWT/PostgREST, old guest-JWT calls, deployed request/body-log redaction, concurrency under real sessions, approved roster/contact/privacy authority and human UAT remain outstanding. All P02–P05 blockers persist. No provider configuration, production deployment, real records, messages or invitations were sent.
