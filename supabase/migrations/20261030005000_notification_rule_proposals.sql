-- P41: immutable notification-rule proposals only. No dispatcher or schedule consumes these.
alter table public.presentation_controls drop constraint presentation_controls_kind_check,
 add constraint presentation_controls_kind_check check(kind in('site','layout','notification'));
alter table public.presentation_drafts drop constraint presentation_drafts_kind_check,
 add constraint presentation_drafts_kind_check check(kind in('site','layout','notification'));

alter function app_private.presentation_actor(uuid,text,text,uuid,boolean)rename to presentation_actor_before_notifications;
create function app_private.presentation_actor(p_term uuid,p_kind text,p_target_kind text,p_target uuid,p_write boolean default false)returns public.term_memberships
language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 if p_kind is distinct from 'notification'then return app_private.presentation_actor_before_notifications(p_term,p_kind,p_target_kind,p_target,p_write);end if;
 m:=app_private.request_actor(p_term,p_write);
 if p_target_kind is distinct from 'term'or p_target is distinct from p_term or not public.has_capability(p_term,'admin.configure')
 then raise exception using errcode='42501',message='command_permission_denied';end if;
 return m;
end$$;

alter function app_private.validate_presentation(text,jsonb)rename to validate_presentation_before_notifications;
create function app_private.validate_presentation(p_kind text,d jsonb)returns void language plpgsql immutable set search_path='' as $$
declare k text;begin
 if p_kind is distinct from 'notification'then perform app_private.validate_presentation_before_notifications(p_kind,d);return;end if;
 if not coalesce(app_private.definition_keys(d,array['version','audience','channel','mode','beforeDays','dueDay','overdueEveryDays','hour','quietStart','quietEnd','template']),false)
  or(select count(*)from jsonb_object_keys(d))<>11 or octet_length(d::text)>2000 or d->'version'is distinct from '1'::jsonb
  or d->>'audience'is distinct from 'current_assignees'or d->>'template'is distinct from 'action_link'
  or d->>'channel'is null or d->>'channel'not in('in_app','email','telegram')
  or d->>'mode'is null or d->>'mode'not in('immediate','digest','mute')or jsonb_typeof(d->'dueDay')is distinct from 'boolean'
 then raise exception using errcode='22023',message='command_validation_failed';end if;
 foreach k in array array['beforeDays','overdueEveryDays','hour','quietStart','quietEnd']loop
  if jsonb_typeof(d->k)is distinct from 'number'or(d->>k)::numeric<>trunc((d->>k)::numeric)
   or(d->>k)::numeric<(case when k in('beforeDays','overdueEveryDays')then 1 else 0 end)
   or(d->>k)::numeric>(case when k in('beforeDays','overdueEveryDays')then 7 else 23 end)
  then raise exception using errcode='22023',message='command_validation_failed';end if;
 end loop;
 if d->'quietStart'=d->'quietEnd'then raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;
revoke all on function app_private.presentation_actor_before_notifications(uuid,text,text,uuid,boolean),app_private.presentation_actor(uuid,text,text,uuid,boolean),
 app_private.validate_presentation_before_notifications(text,jsonb),app_private.validate_presentation(text,jsonb)from public,anon,authenticated,service_role;
