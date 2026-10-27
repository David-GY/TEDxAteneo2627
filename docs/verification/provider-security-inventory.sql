-- Privilege/catalog inventory; no user or business payloads.
select
 (select count(*)from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relkind='r'and not c.relrowsecurity) as tables_without_rls,
 (select count(*)from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relkind='r'and not c.relforcerowsecurity) as tables_without_forced_rls,
 (select count(*)from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relkind='r'and has_table_privilege('anon',c.oid,'SELECT')) as anonymously_selectable_tables,
 (select count(*)from supabase_migrations.schema_migrations) as applied_migrations,
 (select not b.public and b.file_size_limit=5242880 from storage.buckets b where b.id='work-private') as private_bucket_guard,
 has_function_privilege('anon','public.publish_access_change(uuid,text,jsonb,integer,text,text,uuid)','EXECUTE') as anonymous_access_publication_execute,
 has_table_privilege('authenticated','public.finance_cases','SELECT') as authenticated_raw_finance_select,
 has_table_privilege('authenticated','app_private.effective_role_assignments','SELECT') as authenticated_raw_lineage_view_select;
