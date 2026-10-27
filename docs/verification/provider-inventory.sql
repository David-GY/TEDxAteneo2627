-- Catalog/count inventory only; no personal rows, credentials or mutations.
select current_setting('server_version') as postgres_version,
 (select count(*)from information_schema.tables where table_schema='public'and table_type='BASE TABLE') as public_tables,
 (select count(*)from information_schema.columns where table_schema='public') as public_columns,
 (select count(*)from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.prorettype<>'trigger'::regtype) as public_api_functions,
 (select count(*)from auth.users) as auth_users,
 (select count(*)from storage.buckets) as storage_buckets,
 (select count(*)from storage.objects) as storage_objects,
 to_regclass('supabase_migrations.schema_migrations')is not null as migration_tracker_present;
