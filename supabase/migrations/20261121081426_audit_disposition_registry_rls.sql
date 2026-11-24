begin;
-- This trusted registry already denied raw client access. Complete the same
-- private-table RLS defense used by the rest of the application; add no policy,
-- client grant or alternate path to author executable disposition projections.
alter table app_private.disposition_sources enable row level security;
alter table app_private.disposition_sources force row level security;
revoke all on app_private.disposition_sources from public,anon,authenticated,service_role;
commit;
