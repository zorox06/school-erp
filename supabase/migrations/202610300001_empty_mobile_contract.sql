-- OPTIONAL starter contract. Not applied by the build process.
-- Creates empty tables and guarded RPCs. No school, user, student, invoice,
-- message, or example rows are inserted. Keep ENABLE_SCHOOL_DATA=false for now.
begin;

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text
);

create table if not exists public.school_memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('parent', 'teacher', 'admin')),
  active boolean not null default false,
  unique (school_id, user_id, role)
);

-- This small adapter table is temporary. Domain tables can replace it behind
-- the two mobile RPC contracts without rewriting the Flutter presentation.
create table if not exists public.school_content (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  kind text not null check (kind in (
    'child','class','homework','worksheet','timetable','attendance','news',
    'event','conversation','invoice','notification','submission','leave',
    'announcement','message'
  )),
  title text,
  description text,
  category text,
  status text,
  date timestamptz,
  created_by uuid references auth.users(id),
  visible_to uuid[] not null default '{}',
  data jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists membership_actor_idx on public.school_memberships(user_id, school_id) where active;
create index if not exists content_school_kind_idx on public.school_content(school_id, kind, created_at desc);
create index if not exists content_audience_idx on public.school_content using gin(visible_to);

alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.school_memberships enable row level security;
alter table public.school_content enable row level security;

revoke all on public.schools, public.profiles, public.school_memberships, public.school_content from anon, authenticated;
grant select on public.schools, public.profiles, public.school_memberships, public.school_content to authenticated;

create policy membership_self_read on public.school_memberships for select to authenticated
using (user_id = (select auth.uid()));
create policy profile_self_read on public.profiles for select to authenticated
using (id = (select auth.uid()));
create policy school_member_read on public.schools for select to authenticated
using (exists (select 1 from public.school_memberships m where m.school_id = schools.id and m.user_id = (select auth.uid()) and m.active));
create policy content_authorized_read on public.school_content for select to authenticated
using (
  exists (select 1 from public.school_memberships m
    where m.school_id = school_content.school_id and m.user_id = (select auth.uid()) and m.active
      and (m.role = 'admin' or school_content.created_by = (select auth.uid()) or school_content.visible_to @> array[(select auth.uid())]))
);

create or replace function public.mobile_context()
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  actor uuid := auth.uid();
  membership public.school_memberships%rowtype;
  result jsonb;
  pair text[];
  records jsonb;
begin
  if actor is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  select * into membership from public.school_memberships
    where user_id = actor and active and role in ('parent','teacher')
    order by case role when 'teacher' then 0 else 1 end, id limit 1;
  result := jsonb_build_object('school_id', membership.school_id, 'school_name', null,
    'display_name', null, 'role', membership.role,
    'children','[]'::jsonb,'classes','[]'::jsonb,'homework','[]'::jsonb,
    'worksheets','[]'::jsonb,'timetable','[]'::jsonb,'attendance','[]'::jsonb,
    'news','[]'::jsonb,'events','[]'::jsonb,'conversations','[]'::jsonb,
    'invoices','[]'::jsonb,'notifications','[]'::jsonb);
  if membership.school_id is null then return result; end if;
  result := result || jsonb_build_object(
    'school_name', (select name from public.schools where id = membership.school_id),
    'display_name', (select display_name from public.profiles where id = actor));
  foreach pair slice 1 in array array[
    ['children','child'],['classes','class'],['homework','homework'],
    ['worksheets','worksheet'],['timetable','timetable'],['attendance','attendance'],
    ['news','news'],['events','event'],['conversations','conversation'],
    ['invoices','invoice'],['notifications','notification']
  ] loop
    select coalesce(jsonb_agg(entry.payload order by entry.created_at desc), '[]'::jsonb) into records
    from (select c.created_at, c.data || jsonb_build_object(
        'id',c.id,'title',c.title,'description',c.description,'category',c.category,
        'status',c.status,'date',c.date) as payload
      from public.school_content c
      where c.school_id = membership.school_id and c.kind = pair[2]
      order by c.created_at desc limit 100) entry;
    result := jsonb_set(result, array[pair[1]], records);
  end loop;
  return result;
end;
$$;

create or replace function public.mobile_create_item(item_kind text, item_data jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  membership public.school_memberships%rowtype;
  target public.school_content%rowtype;
  related public.school_content%rowtype;
  audience uuid[];
  new_id uuid;
begin
  if actor is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if item_kind not in ('homework','worksheet','leave','submission','announcement','message') then
    raise exception 'This operation is not available' using errcode = '42501';
  end if;
  if length(coalesce(item_data->>'title','')) > 140 or length(coalesce(item_data->>'description','')) > 4000 then
    raise exception 'Content exceeds allowed length' using errcode = '22023';
  end if;
  if item_kind in ('homework','worksheet','announcement') then
    select * into target from public.school_content where id = (item_data->>'class_id')::uuid and kind = 'class';
  elsif item_kind = 'leave' then
    select * into target from public.school_content where id = (item_data->>'child_id')::uuid and kind = 'child';
  elsif item_kind = 'submission' then
    select * into target from public.school_content where id = (item_data->>'linked_id')::uuid and kind = 'homework';
  else
    select * into target from public.school_content where id = (item_data->>'conversation_id')::uuid and kind = 'conversation';
  end if;
  if target.id is null then raise exception 'An authorized school resource is required' using errcode = '42501'; end if;
  select * into membership from public.school_memberships
    where user_id = actor and school_id = target.school_id and active
      and (role = 'admin' or (item_kind in ('homework','worksheet','announcement') and role = 'teacher')
        or (item_kind in ('leave','submission') and role = 'parent') or item_kind = 'message')
    order by case role when 'admin' then 0 else 1 end limit 1;
  if membership.id is null or not (membership.role = 'admin' or target.visible_to @> array[actor]) then
    raise exception 'Resource access denied' using errcode = '42501';
  end if;
  audience := array(select distinct unnest(target.visible_to || array[actor, target.created_by]));
  audience := array_remove(audience, null);
  if item_kind in ('homework','worksheet','announcement') then
    select array_agg(distinct expanded.person) into audience from (
      select unnest(audience) as person
      union all
      select unnest(child.visible_to) from public.school_content child
        where child.school_id = target.school_id and child.kind = 'child'
          and child.data->>'class_id' = target.id::text
    ) expanded;
  end if;
  if item_kind = 'submission' then
    select * into related from public.school_content where id = (item_data->>'child_id')::uuid and kind = 'child'
      and school_id = target.school_id and visible_to @> array[actor];
    if related.id is null or related.data->>'class_id' is distinct from target.data->>'class_id' then
      raise exception 'Child and homework must belong to the same authorized class' using errcode = '42501';
    end if;
    -- Completed work is private to the child's guardians and responsible staff,
    -- never all parents who can read the original class homework.
    audience := array_remove(array(select distinct unnest(related.visible_to || array[actor, target.created_by])), null);
  end if;
  insert into public.school_content(school_id, kind, title, description, category, status, date, created_by, visible_to, data)
  values(target.school_id, item_kind, nullif(trim(item_data->>'title'),''), nullif(trim(item_data->>'description'),''),
    nullif(trim(item_data->>'category'),''), case when item_kind = 'leave' then 'pending' else 'published' end,
    nullif(item_data->>'date','')::timestamptz, actor, audience,
    jsonb_strip_nulls(jsonb_build_object('class_id', case when target.kind = 'class' then target.id::text else item_data->>'class_id' end,
      'child_id', item_data->>'child_id', 'linked_id',item_data->>'linked_id',
      'conversation_id',item_data->>'conversation_id','until',item_data->>'until')))
  returning id into new_id;
  return new_id;
end;
$$;

revoke all on function public.mobile_context() from public, anon;
revoke all on function public.mobile_create_item(text,jsonb) from public, anon;
grant execute on function public.mobile_context(), public.mobile_create_item(text,jsonb) to authenticated;
commit;
