# Local calendar and explicit event copies

P31 adds governed local events and live source-linked dates. It does not connect Google Calendar or reserve rooms. Source of truth stays in the app; there are no imported Google events, sync credentials/jobs/mappings or fabricated last-sync times. The UI reports that no sync has run. P53 owns any later automatic API integration.

## Source, visibility and authority

calendar_events contains only local typed records, keyed to a neutral restricted announcement spine. The spine carries the existing work version/idempotency/audit/outbox contract; it contains only Calendar entry and blank body/summary, never the event title, description or location. Those fields stay in forced-RLS/raw-grant-denied calendar_events and immutable calendar_event_versions. Local origin is fixed by this typed interface, projected as local; no caller can supply or change a source kind.

Active core owners can create restricted personal events. Explicit term admin.configure publishes core-safe events, with a required content acknowledgment; explicit current committee.manage scope publishes committee events. Commands check both old and new scope, current admission/deployment/term, expected version and exact actor/key/payload. No head/PM label grants authority. Real calendar-steward mapping and publishing/privacy policy remain institutional inputs; no real role is seeded.

Read scope precedes text/location/counts/options/pagination: core events require current core workspace access; committee events require current deployment or independent exact-record access; restricted events require existing exact-record detail permission. Guests see only independently granted records through the existing live invitation/email/sponsor/expiry predicates. No automatic guest-wide core access. Generic spine edits cannot alter calendar content/ownership/unit/archive; existing explicit grant/revoke commands retain their scoped, versioned path. Public/private histories are never mixed into shared reads.

Deadlines and planned starts are live projections of permitted task/deliverable sources. Stable deadline:<work-id>/start:<work-id> keys and source links avoid duplicate editable date records. Changes follow the actual source; edit the source to change its date. Date-only markers are all-day; a timed deadline uses a one-minute marker at the exact original deadline without changing that deadline. Restricted source titles become neutral Private task/deliverable labels, and their descriptions/bodies/locations are not copied. No request, finance, feedback or mentoring package is joined into calendar data. Ordinary source information exports only after its independent source scope and current core access pass. Unit/restricted events and guest-only views have no export UI.

Location is informational and explicitly does not certify a reservation or confirmed room. Future room/resource integration must supply authoritative booking evidence rather than relabeling this text as reserved.

## Dates and copies

Manual timed inputs use explicit Manila offsets; stored instants export in UTC. Manual all-day UI uses inclusive first/last days; storage and ICS use an exclusive end. Term-bound finite nonempty ranges, strict payload types and current authority are enforced by SQL. Cancelled records are retained with stable UID and increasing source version, visible labels and STATUS:CANCELLED in ICS; no Google template is offered for a cancellation.

Single-event export first fetches the currently permitted event again. ICS uses CRLF, escaped text, UTF-8-safe75-octet folding, stable source UID, sequence and modification time. The choices follow [RFC5545 sections3.1 and3.6.1](https://www.rfc-editor.org/rfc/rfc5545). Google preparation builds only an event-template URL; a separate visible link states that opening Google sends the core-safe title/dates/description/location and creates a copy, not synchronization. No external page is opened by tests. Private data cannot export through this UI. Previously downloaded/imported copies cannot be recalled by access revocation, edits or cancellation; both UI and exported description say to check the current app record.

There is no bulk calendar feed, Google token flow, automatic publishing, import, provider update/cancellation or continuous sync. Actual ICS-client and Google template interoperability remain human/provider gates; local golden-file/URL checks are not that proof.

## UI, transaction and verification boundaries

/calendar supports month grid and chronological list; narrow screens use the list. Up to100 currently permitted events per page, safe committee options, explicit paging notices, Manila dates, source/cancellation/version labels, visible focus and44px controls. Focus/visibility and30second visible-page checks reauthorize; rechecking/errors hide previous rows and prepared links. This is not instantaneous push revocation. Direct source links and export preparation recheck actual scope; already authorized downloaded copies remain independent artifacts.

Forms reuse identity-bound in-memory decision memory. Conflicts retain inputs; explicit refresh loads the current version. Uncertain/malformed success locks fields and recovers the identical payload/key. A calendar mutation stores event/history/work version/redacted audit/outbox atomically. The P29 READ COMMITTED term lock serializes current role/term/source inputs; actual independent-session contention/deadlock and revocation races are not proven by sequential fixtures.

Actual checks and failure ledger: docs/build/steps/P31.md; P31-domain/browser evidence and ics.test.ts. All inherited provider/JWT/authority/privacy/retention/concurrency/human gates persist. No deployment, provider configuration, external messages, reservations or P32 work occurred.
