-- P62 native recovery found associative BETWEEN/AND trees introduced by P58,
-- P59 and P61 which pg_dump flattens. Preserve the exact predicates and names,
-- as P47's earlier canonicalization did; never bless unrelated schema drift.
begin;
do $$begin
 if not app_private.disposition_catalog_current()then raise exception using errcode='55000',message='privacy_disposition_catalog_changed';end if;
end $$;
alter table app_private.inventory_items
 drop constraint inventory_items_label_check,drop constraint inventory_items_location_check,
 add constraint inventory_items_label_check check(length(btrim(label))>=1 and length(btrim(label))<=160 and label!~'[[:cntrl:]]'),
 add constraint inventory_items_location_check check(length(btrim(location))>=1 and length(btrim(location))<=160 and location!~'[[:cntrl:]]');
alter table app_private.learning_goals drop constraint learning_goals_title_check,
 add constraint learning_goals_title_check check(length(btrim(title))>=1 and length(btrim(title))<=160 and title!~'[[:cntrl:]]');
alter table app_private.learning_checkins drop constraint learning_checkins_title_check,
 add constraint learning_checkins_title_check check(length(btrim(title))>=1 and length(btrim(title))<=160 and title!~'[[:cntrl:]]');
alter table app_private.evaluation_launch_approvals drop constraint evaluation_launch_approvals_complaints_url_check,
 add constraint evaluation_launch_approvals_complaints_url_check check(length(complaints_url)>=11 and length(complaints_url)<=1008 and complaints_url~'^https://[^[:space:]]+$');
update app_private.disposition_sources set structure_hash=app_private.disposition_structure(source_key)
 where source_key in('app_private.inventory_items','app_private.learning_goals','app_private.learning_checkins','app_private.evaluation_launch_approvals');
commit;
