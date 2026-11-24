-- Governed readiness checks current contributions, their accepted handoffs and
-- independent authority before changing the deliverable state. The pre-readiness
-- trigger rejected all contributions, even after those checks succeeded.
drop trigger synergy_acceptance_gate on public.deliverables;
drop function app_private.synergy_parent_gate();
