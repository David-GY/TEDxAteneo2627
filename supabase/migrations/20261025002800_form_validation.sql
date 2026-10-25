-- P20 validates a published form only. No case, sequence, approval or submission is created.
create function public.request_form_options(p_term_id uuid,p_type_id uuid,p_work_item_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 result:=public.read_request_catalog(p_term_id,p_type_id);
 if result is null or jsonb_array_length(result->'items')<>1 then return null;end if;
 if p_work_item_id is not null and not exists(select 1 from public.work_items where id=p_work_item_id and term_id=p_term_id and archived_at is null and public.can_access_work(id,'edit')) then return null;end if;
 return jsonb_build_object(
 'members',(select coalesce(jsonb_agg(jsonb_build_object('id',d.member_id,'label',d.display_name) order by d.display_name,d.member_id),'[]') from (select d.* from public.read_directory(p_term_id) d join public.term_memberships m on m.member_id=d.member_id and m.term_id=p_term_id and m.membership_kind='core' and m.status='active' and m.joined_at<=statement_timestamp() and m.ends_at>statement_timestamp() order by d.display_name,d.member_id limit 200) d),
 'units',(select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'label',u.name) order by u.name,u.id),'[]') from (select id,name from public.org_units where term_id=p_term_id and archived_at is null order by name,id limit 200) u),
 'files',(select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'label',a.filename) order by a.filename,a.id),'[]') from (select a.id,a.filename from public.assets a join public.work_items w on w.id=a.origin_work_item_id and w.term_id=p_term_id where p_work_item_id is not null and a.state='finalized' and (a.classification='ordinary' or exists(select 1 from public.request_types where id=p_type_id and payload_classification='restricted')) and public.can_access_work(a.origin_work_item_id,'detail') and (a.origin_work_item_id=p_work_item_id or exists(select 1 from public.asset_links l where l.asset_id=a.id and l.work_item_id=p_work_item_id)) order by a.filename,a.id limit 100) a));
end$$;

create function app_private.form_condition(c jsonb, v jsonb) returns boolean
language plpgsql immutable set search_path='' as $$declare x jsonb; operand jsonb;op text:=c->>'op';begin
 if c is null then return false;end if;
 if op in('and','or') then
  for x in select value from jsonb_array_elements(c->'conditions') loop
   if op='and' and not app_private.form_condition(x,v) then return false;end if;
   if op='or' and app_private.form_condition(x,v) then return true;end if;
  end loop;return op='and';
 end if;
 if not(v?(c->>'field')) then return false;end if;operand:=v->(c->>'field');
 if op='eq' then return operand=c->'value';elsif op='in' then return exists(select 1 from jsonb_array_elements(c->'value') entry where entry=operand);end if;
 if jsonb_typeof(operand)<>'number' or jsonb_typeof(c->'value')<>'number' then return false;end if;
 return case op when 'gt' then (operand#>>'{}')::numeric>(c->>'value')::numeric when 'gte' then (operand#>>'{}')::numeric>=(c->>'value')::numeric when 'lt' then (operand#>>'{}')::numeric<(c->>'value')::numeric when 'lte' then (operand#>>'{}')::numeric<=(c->>'value')::numeric else false end;
end$$;
create function app_private.form_date(v text,timed boolean) returns boolean language plpgsql immutable set search_path='' as $$begin
 if v is null or substring(v,1,4)::integer<1 then return false;end if;
 if not timed then return v~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' and to_char(v::date,'YYYY-MM-DD')=v;end if;
 return v~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]{3})?Z$' and substring(v,12,2)::int<24 and substring(v,15,2)::int<60 and substring(v,18,2)::int<60 and (v::timestamptz at time zone 'UTC')::date=substring(v,1,10)::date;
 exception when others then return false;end$$;

create function app_private.form_url(v text) returns boolean language plpgsql immutable set search_path='' as $$
declare host text:=split_part(split_part(v,'/',3),':',1);port text:=split_part(split_part(v,'/',3),':',2);p text;parts text[]:=string_to_array(host,'.');begin
 if v !~ '^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[^[:space:]]*)?$' or v~'@' or length(host)>253 or (port<>'' and (port::int<1 or port::int>65535)) then return false;end if;
 foreach p in array parts loop if p!~'^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9])$' then return false;end if;end loop;
 if host~'^[0-9.]+$' then if array_length(parts,1)<>4 then return false;end if;foreach p in array parts loop if length(p)>3 or p::int>255 or p::int::text<>p then return false;end if;end loop;end if;
 return true;exception when others then return false;end$$;
create function app_private.validate_form_fields(defs jsonb,input jsonb,options jsonb,centavos bigint,prefix text default '',top_level boolean default true) returns jsonb
language plpgsql immutable set search_path='' as $$
declare f jsonb;v jsonb; k text;path text;typ text;code text;out jsonb:='{}';errors jsonb:='{}';snapshots jsonb:='{}';required boolean;choices jsonb;selected jsonb;x jsonb;row_result jsonb;rows jsonb;idx integer;lines integer:=0;txt text;
begin
 if jsonb_typeof(input) is distinct from 'object' then return jsonb_build_object('errors',jsonb_build_object(prefix||'$form','type'),'values','{}'::jsonb,'snapshots','{}'::jsonb,'lines',0);end if;
 for k in select jsonb_object_keys(input) loop
  if not exists(select 1 from jsonb_array_elements(defs) entry where entry->>'key'=k) then errors:=errors||jsonb_build_object(prefix||k,'unknown');end if;
 end loop;
 for f in select value from jsonb_array_elements(defs) loop
  k:=f->>'key';path:=prefix||k;typ:=f->>'type';v:=input->k;code:=null;
  if f?'visibleWhen' and not app_private.form_condition(f->'visibleWhen',out) then
   if input?k then errors:=errors||jsonb_build_object(path,'hidden');end if;continue;
  end if;
  required:=(f->>'required')::boolean or app_private.form_condition(f->'requiredWhen',out);
  if coalesce(f->>'storage','custom')<>'custom' then
   if input?k then errors:=errors||jsonb_build_object(path,'protected');end if;
   if top_level and typ='currency' and k='requested_centavos' and f->>'storage'='finance' then
    if centavos is null and required then errors:=errors||jsonb_build_object(path,'required');
    elsif centavos is not null and (centavos<0 or centavos>9007199254740991 or (f?'min' and centavos<(f->>'min')::numeric) or (f?'max' and centavos>(f->>'max')::numeric)) then errors:=errors||jsonb_build_object(path,'range');end if;
   elsif required then errors:=errors||jsonb_build_object(path,'protected');end if;continue;
  end if;
  if v is null or v='null'::jsonb or v='""'::jsonb or v='[]'::jsonb or (jsonb_typeof(v)='string' and btrim(v#>>'{}',E' \t\n\r')='') then
   if required then errors:=errors||jsonb_build_object(path,'required');end if;continue;
  end if;
  txt:=v#>>'{}';
  if typ in('short_text','long_text','url') then
   if jsonb_typeof(v)<>'string' or length(txt)>coalesce((f->>'maxLength')::int,case typ when 'short_text' then 240 when 'url' then 2048 else 20000 end) or translate(txt,E'\t\n\r','')~'[[:cntrl:]]' then code:='type';
   elsif typ='url' and not app_private.form_url(txt) then code:='type';end if;
  elsif typ='number' then
   if jsonb_typeof(v)<>'number' then code:='type';elsif abs(txt::numeric)>9007199254740991 or (f?'min' and txt::numeric<(f->>'min')::numeric) or (f?'max' and txt::numeric>(f->>'max')::numeric) then code:='range';end if;
  elsif typ='checkbox' then if jsonb_typeof(v)<>'boolean' then code:='type';elsif required and v<>'true'::jsonb then code:='required';end if;
  elsif typ in('date','date_time') then if jsonb_typeof(v)<>'string' or not app_private.form_date(txt,typ='date_time') then code:='type';end if;
  elsif typ in('single_choice','multi_choice','member','unit','file') then
   choices:=case typ when 'single_choice' then f->'options' when 'multi_choice' then f->'options' when 'member' then options->'members' when 'unit' then options->'units' when 'file' then options->'files' end;
   selected:=case when typ in('single_choice','member','unit') then jsonb_build_array(v) else v end;
   if jsonb_typeof(selected)<>'array' then code:=case when typ='multi_choice' then 'choice' else 'ineligible' end;
   elsif jsonb_array_length(selected)>coalesce((f->>'maxItems')::int,1) or (select count(distinct entry) from jsonb_array_elements(selected) entry)<>jsonb_array_length(selected) or exists(select 1 from jsonb_array_elements(selected) entry where jsonb_typeof(entry)<>'string' or not exists(select 1 from jsonb_array_elements(choices) o where o->'id'=entry)) then code:=case when typ in('single_choice','multi_choice') then 'choice' else 'ineligible' end;
   else snapshots:=snapshots||jsonb_build_object(path,(select coalesce(jsonb_agg(o order by chosen.ordinality),'[]') from jsonb_array_elements(selected) with ordinality chosen(value,ordinality) join lateral jsonb_array_elements(choices) o on o->'id'=chosen.value));end if;
  elsif typ='line_items' then
   if jsonb_typeof(v)<>'array' then code:='quota';
   elsif jsonb_array_length(v)>(f->>'maxItems')::int or lines+jsonb_array_length(v)>100 then code:='quota';
   else rows:='[]';idx:=0;lines:=lines+jsonb_array_length(v);
    for x in select value from jsonb_array_elements(v) loop
     if jsonb_typeof(x)<>'object' then errors:=errors||jsonb_build_object(path||'.'||idx,'type');
     else row_result:=app_private.validate_form_fields(f->'itemFields',x,options,null,path||'.'||idx||'.',false);errors:=errors||(row_result->'errors');snapshots:=snapshots||(row_result->'snapshots');rows:=rows||jsonb_build_array(row_result->'values');end if;idx:=idx+1;
    end loop;out:=out||jsonb_build_object(k,rows);
   end if;
  else code:='protected';end if;
  if code is not null then errors:=errors||jsonb_build_object(path,code);elsif typ<>'line_items' then out:=out||jsonb_build_object(k,v);end if;
 end loop;
 return jsonb_build_object('errors',errors,'values',out,'snapshots',snapshots,'lines',lines);
end$$;
create function public.validate_request_form(p_term_id uuid,p_type_id uuid,p_form_version_id uuid,p_values jsonb,p_requested_centavos bigint default null,p_work_item_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare t public.request_types;f public.form_versions;options jsonb;r jsonb;errors jsonb;valid boolean;begin
 options:=public.request_form_options(p_term_id,p_type_id,p_work_item_id);
 if options is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select * into t from public.request_types where id=p_type_id and term_id=p_term_id and archived_at is null;
 if t.form_version_id is distinct from p_form_version_id then raise exception using errcode='40001',message='command_stale_version';end if;
 select * into f from public.form_versions where id=p_form_version_id and request_type_id=t.id and state='published';
 perform app_private.validate_form_definition(f.schema_json,t.payload_classification='restricted');
 if jsonb_typeof(p_values) is distinct from 'object' or octet_length(p_values::text)>100000 then errors:='{"$form":"quota"}';
 else
  r:=app_private.validate_form_fields(f.schema_json->'fields',p_values,options,p_requested_centavos);errors:=r->'errors';
  if p_requested_centavos is not null and not exists(select 1 from jsonb_array_elements(f.schema_json->'fields') field where field->>'key'='requested_centavos' and field->>'type'='currency' and field->>'storage'='finance' and (not(field?'visibleWhen') or app_private.form_condition(field->'visibleWhen',r->'values'))) then errors:=errors||'{"requested_centavos":"protected"}';end if;
 end if;
 valid:=errors='{}'::jsonb;
 return jsonb_build_object('valid',valid,'errors',errors,'values',case when valid then r->'values' end,'snapshots',case when valid then r->'snapshots' end,'requestedCentavos',case when valid then p_requested_centavos end);
end$$;
revoke all on function public.request_form_options(uuid,uuid,uuid),public.validate_request_form(uuid,uuid,uuid,jsonb,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.request_form_options(uuid,uuid,uuid),public.validate_request_form(uuid,uuid,uuid,jsonb,bigint,uuid) to authenticated;
revoke all on function app_private.form_condition(jsonb,jsonb),app_private.form_date(text,boolean),app_private.form_url(text),app_private.validate_form_fields(jsonb,jsonb,jsonb,bigint,text,boolean) from public,anon,authenticated,service_role;
