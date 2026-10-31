-- Phase 1. Apply AFTER 202610300001_empty_mobile_contract.sql.
-- No seeded business data. All provisioning is trusted administration only.
begin;
alter table public.school_memberships drop constraint if exists school_memberships_role_check;
alter table public.school_memberships add constraint school_memberships_role_check
  check (role in ('admin','principal','teacher','parent','student'));

create table public.erp_students (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools,
  user_id uuid references auth.users, name text not null check(length(name) between 1 and 160), roll text,
  unique(school_id,id)
);
create table public.erp_class_students (
  school_id uuid not null, class_id uuid not null references public.school_content,
  student_id uuid not null, primary key(school_id,class_id,student_id),
  foreign key(school_id,student_id) references public.erp_students(school_id,id)
);
create table public.erp_class_teachers (
  school_id uuid not null references public.schools, class_id uuid not null references public.school_content,
  user_id uuid not null references auth.users, primary key(school_id,class_id,user_id)
);
create table public.erp_guardians (
  school_id uuid not null, student_id uuid not null, user_id uuid not null references auth.users,
  primary key(school_id,student_id,user_id), foreign key(school_id,student_id) references public.erp_students(school_id,id)
);
create sequence public.erp_attendance_revision;
create table public.erp_attendance (
  school_id uuid not null, student_id uuid not null, class_id uuid not null references public.school_content,
  day date not null, status text not null check(status in ('present','absent','late','leave')),
  reason text check(reason in ('sick','excused','unexcused')), operation_id uuid not null,
  client_time timestamptz not null, updated_by uuid not null references auth.users,
  updated_at timestamptz not null default clock_timestamp(), revision bigint not null,
  primary key(school_id,student_id,day), foreign key(school_id,student_id) references public.erp_students(school_id,id),
  check(status <> 'present' or reason is null)
);
create index erp_attendance_delta_idx on public.erp_attendance(school_id,revision);
create table public.erp_notices (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools,
  title text not null check(length(title) between 1 and 140), body text not null check(length(body) between 1 and 8000),
  important boolean not null default false, published_at timestamptz not null default now(),
  created_by uuid not null references auth.users, unique(school_id,id)
);
create index erp_notices_page_idx on public.erp_notices(school_id,important desc,published_at desc,id desc);
create table public.erp_notice_receipts (
  school_id uuid not null, notice_id uuid not null, user_id uuid not null references auth.users,
  read_at timestamptz not null default now(), acknowledged_at timestamptz,
  primary key(notice_id,user_id), foreign key(school_id,notice_id) references public.erp_notices(school_id,id)
);
create table public.erp_device_tokens (
  token text primary key check(length(token) between 20 and 4096), school_id uuid not null references public.schools,
  user_id uuid not null references auth.users, platform text not null check(platform in ('android','ios')),
  updated_at timestamptz not null default now()
);
create table public.erp_notification_outbox (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools,
  user_id uuid not null references auth.users, student_id uuid references public.erp_students,
  attendance_day date, attendance_operation uuid, notice_id uuid references public.erp_notices,
  category text not null check(category in ('absence','notice')), dedupe_key text not null unique,
  created_at timestamptz not null default now(), delivered_at timestamptz,
  attempts integer not null default 0, next_attempt timestamptz not null default now(),
  lease_until timestamptz, lease_id uuid, last_error text
);
create table public.erp_audit_events (
  id bigint generated always as identity primary key, school_id uuid not null references public.schools,
  actor uuid not null references auth.users, action text not null,
  entity_id text not null, before_value jsonb, after_value jsonb, at timestamptz not null default now()
);

create function public.erp_has_role(p_school uuid, p_roles text[]) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.school_memberships m where m.school_id=p_school
    and m.user_id=auth.uid() and m.active and m.role=any(p_roles));
$$;
create function public.erp_can_class(p_school uuid,p_class uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.school_content c where c.id=p_class and c.school_id=p_school and c.kind='class')
    and (public.erp_has_role(p_school,array['admin','principal']) or
      (public.erp_has_role(p_school,array['teacher']) and exists(select 1 from public.erp_class_teachers t
        where t.school_id=p_school and t.class_id=p_class and t.user_id=auth.uid())));
$$;
create function public.erp_can_student(p_school uuid,p_student uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.erp_has_role(p_school,array['admin','principal'])
    or (public.erp_has_role(p_school,array['parent']) and exists(select 1 from public.erp_guardians g
      where g.school_id=p_school and g.student_id=p_student and g.user_id=auth.uid()))
    or (public.erp_has_role(p_school,array['student']) and exists(select 1 from public.erp_students s
      where s.school_id=p_school and s.id=p_student and s.user_id=auth.uid()))
    or exists(select 1 from public.erp_class_students cs where cs.school_id=p_school and cs.student_id=p_student
      and public.erp_can_class(p_school,cs.class_id));
$$;

alter table public.erp_students enable row level security;
alter table public.erp_class_students enable row level security;
alter table public.erp_class_teachers enable row level security;
alter table public.erp_guardians enable row level security;
alter table public.erp_attendance enable row level security;
alter table public.erp_notices enable row level security;
alter table public.erp_notice_receipts enable row level security;
alter table public.erp_device_tokens enable row level security;
alter table public.erp_notification_outbox enable row level security;
alter table public.erp_audit_events enable row level security;
revoke all on public.erp_students,public.erp_class_students,public.erp_class_teachers,public.erp_guardians,
  public.erp_attendance,public.erp_notices,public.erp_notice_receipts,public.erp_device_tokens,
  public.erp_notification_outbox,public.erp_audit_events from anon,authenticated;
grant select on public.erp_students,public.erp_class_students,public.erp_class_teachers,public.erp_guardians,
  public.erp_attendance,public.erp_notices,public.erp_notice_receipts,public.erp_audit_events to authenticated;
create policy students_authorized on public.erp_students for select to authenticated using(public.erp_can_student(school_id,id));
create policy roster_authorized on public.erp_class_students for select to authenticated using(public.erp_can_student(school_id,student_id));
create policy teacher_self on public.erp_class_teachers for select to authenticated using(user_id=auth.uid() and public.erp_has_role(school_id,array['teacher','admin','principal']));
create policy guardian_self on public.erp_guardians for select to authenticated using(user_id=auth.uid() and public.erp_has_role(school_id,array['parent','admin','principal']));
create policy attendance_authorized on public.erp_attendance for select to authenticated using(public.erp_can_student(school_id,student_id));
create policy notices_authorized on public.erp_notices for select to authenticated using(public.erp_has_role(school_id,array['admin','principal','teacher','parent','student']));
create policy receipt_self on public.erp_notice_receipts for select to authenticated using(user_id=auth.uid() and public.erp_has_role(school_id,array['admin','principal','teacher','parent','student']));
create policy audit_leadership on public.erp_audit_events for select to authenticated using(public.erp_has_role(school_id,array['admin','principal']));

create function public.erp_roster(p_school uuid,p_class uuid,p_after uuid default null,p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if not public.erp_can_class(p_school,p_class) then raise exception 'Class access denied' using errcode='42501'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(r) order by r.id),'[]'::jsonb) from
    (select s.id,cs.class_id,s.name,s.roll from public.erp_class_students cs join public.erp_students s
      on s.id=cs.student_id and s.school_id=cs.school_id where cs.school_id=p_school and cs.class_id=p_class
      and (p_after is null or s.id>p_after) order by s.id limit greatest(1,least(coalesce(p_limit,100),100))) r);
end;
$$;

create function public.erp_sync_attendance(p_school uuid,p_changes jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb; old public.erp_attendance%rowtype; saved public.erp_attendance%rowtype;
  student uuid; classroom uuid; event_time timestamptz; op uuid; the_day date; result jsonb := '[]'::jsonb;
begin
  if not public.erp_has_role(p_school,array['teacher','principal','admin']) then raise exception 'Staff access required' using errcode='42501'; end if;
  if jsonb_typeof(p_changes)<>'array' or jsonb_array_length(p_changes) not between 1 and 500 then raise exception 'Invalid changes' using errcode='22023'; end if;
  -- Serializes commits and delta watermarks per school, avoiding sequence/cursor gaps.
  perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
  for c in select value from jsonb_array_elements(p_changes) loop
    student:=(c->>'student_id')::uuid; classroom:=(c->>'class_id')::uuid;
    event_time:=(c->>'client_time')::timestamptz; op:=(c->>'operation_id')::uuid; the_day:=(c->>'day')::date;
    if not public.erp_can_class(p_school,classroom) or not exists(select 1 from public.erp_class_students cs
      where cs.school_id=p_school and cs.class_id=classroom and cs.student_id=student) then
      raise exception 'Student or class access denied' using errcode='42501'; end if;
    if event_time is null or op is null or the_day is null or c->>'status' is null
      or c->>'status' not in ('present','absent','late','leave')
      or (c->>'reason' is not null and c->>'reason' not in ('sick','excused','unexcused'))
      or (c->>'status'='present' and c->>'reason' is not null)
      or event_time > now()+interval '5 minutes' or event_time < now()-interval '7 days'
      or the_day > current_date+1 or the_day < current_date-366 then
      raise exception 'Invalid attendance draft' using errcode='22023'; end if;
    select * into old from public.erp_attendance where school_id=p_school and student_id=student and day=the_day;
    if old.student_id is null or (event_time,op) > (old.client_time,old.operation_id) then
      insert into public.erp_attendance(school_id,student_id,class_id,day,status,reason,operation_id,client_time,updated_by,revision)
        values(p_school,student,classroom,the_day,c->>'status',c->>'reason',op,event_time,auth.uid(),nextval('public.erp_attendance_revision'))
        on conflict(school_id,student_id,day) do update set class_id=excluded.class_id,status=excluded.status,
          reason=excluded.reason,operation_id=excluded.operation_id,client_time=excluded.client_time,updated_by=excluded.updated_by,
          updated_at=clock_timestamp(),revision=excluded.revision returning * into saved;
      insert into public.erp_audit_events(school_id,actor,action,entity_id,before_value,after_value)
        values(p_school,auth.uid(),'attendance.edit',student::text||'/'||the_day::text,
          case when old.student_id is null then null else to_jsonb(old) end,to_jsonb(saved));
      if saved.status='absent' and old.status is distinct from 'absent' then
        insert into public.erp_notification_outbox(school_id,user_id,student_id,attendance_day,attendance_operation,category,dedupe_key)
          select p_school,g.user_id,student,the_day,op,'absence',op::text||':'||g.user_id::text
          from public.erp_guardians g where g.school_id=p_school and g.student_id=student
            and exists(select 1 from public.school_memberships m where m.school_id=p_school and m.user_id=g.user_id and m.active and m.role='parent')
          on conflict(dedupe_key) do nothing;
      end if;
    else saved:=old;
    end if;
    result:=result||jsonb_build_array(to_jsonb(saved));
  end loop;
  return result;
end;
$$;

create function public.erp_attendance_delta(p_school uuid,p_cursor text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare records jsonb; cursor_value bigint := coalesce(nullif(p_cursor,''),'0')::bigint; next_cursor bigint;
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) then raise exception 'School access denied' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
  select coalesce(jsonb_agg(to_jsonb(r) order by r.revision),'[]'::jsonb), max(r.revision) into records,next_cursor from
    (select a.* from public.erp_attendance a where a.school_id=p_school and a.revision>cursor_value
      and public.erp_can_student(p_school,a.student_id) order by a.revision limit 100) r;
  return jsonb_build_object('records',records,'cursor',coalesce(next_cursor,cursor_value)::text,'has_more',jsonb_array_length(records)=100);
end;
$$;

create function public.erp_notices(p_school uuid,p_child uuid default null,p_after text default null,p_limit integer default 30)
returns jsonb language plpgsql security definer set search_path='' as $$
declare flag boolean; stamp timestamptz; last_id uuid;
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student'])
    or (p_child is not null and not public.erp_can_student(p_school,p_child)) then raise exception 'School access denied' using errcode='42501'; end if;
  if p_after is not null then flag:=split_part(p_after,'|',1)='1'; stamp:=split_part(p_after,'|',2)::timestamptz; last_id:=split_part(p_after,'|',3)::uuid; end if;
  return (select coalesce(jsonb_agg(to_jsonb(r) order by r.important desc,r.published_at desc,r.id desc),'[]'::jsonb) from
    (select n.id,n.title,n.body,n.important,n.published_at,(r.read_at is not null) as read,(r.acknowledged_at is not null) as acknowledged
      from public.erp_notices n left join public.erp_notice_receipts r on r.notice_id=n.id and r.user_id=auth.uid()
      where n.school_id=p_school and (p_after is null or (n.important,n.published_at,n.id)<(flag,stamp,last_id))
      order by n.important desc,n.published_at desc,n.id desc limit greatest(1,least(coalesce(p_limit,30),100))) r);
end;
$$;

create function public.erp_notice_receipt(p_school uuid,p_notice uuid,p_acknowledge boolean default false) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student'])
    or not exists(select 1 from public.erp_notices n where n.school_id=p_school and n.id=p_notice) then raise exception 'Notice access denied' using errcode='42501'; end if;
  insert into public.erp_notice_receipts(school_id,notice_id,user_id,acknowledged_at)
    values(p_school,p_notice,auth.uid(),case when p_acknowledge then now() else null end)
    on conflict(notice_id,user_id) do update set acknowledged_at=coalesce(erp_notice_receipts.acknowledged_at,excluded.acknowledged_at);
end;
$$;

create function public.erp_publish_notice(p_school uuid,p_title text,p_body text,p_important boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare notice uuid;
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher']) then raise exception 'Staff access required' using errcode='42501'; end if;
  insert into public.erp_notices(school_id,title,body,important,created_by) values(p_school,btrim(p_title),btrim(p_body),coalesce(p_important,false),auth.uid()) returning id into notice;
  insert into public.erp_notification_outbox(school_id,user_id,notice_id,category,dedupe_key)
    select p_school,m.user_id,notice,'notice',notice::text||':'||m.user_id::text from public.school_memberships m
      where m.school_id=p_school and m.active and m.user_id<>auth.uid() on conflict(dedupe_key) do nothing;
  return notice;
end;
$$;
create function public.erp_register_device(p_school uuid,p_token text,p_platform text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) then raise exception 'School access denied' using errcode='42501'; end if;
  insert into public.erp_device_tokens(token,school_id,user_id,platform) values(p_token,p_school,auth.uid(),p_platform)
    on conflict(token) do update set school_id=excluded.school_id,user_id=excluded.user_id,platform=excluded.platform,updated_at=now();
end;
$$;
create function public.erp_unregister_device(p_token text) returns void
language sql security definer set search_path='' as $$
  delete from public.erp_device_tokens where token=p_token and user_id=auth.uid();
$$;

-- Only a server function using the service role may claim push delivery work.
create function public.erp_claim_notifications() returns setof public.erp_notification_outbox
language plpgsql security definer set search_path='' as $$
begin
  return query update public.erp_notification_outbox q set lease_until=now()+interval '2 minutes',lease_id=gen_random_uuid(),attempts=q.attempts+1
    where q.id in (select o.id from public.erp_notification_outbox o where o.delivered_at is null and o.attempts<10
      and o.next_attempt<=now() and (o.lease_until is null or o.lease_until<now()) order by o.created_at for update skip locked limit 30)
    returning q.*;
end;
$$;

-- Lock down ALL helper/function execute privileges; no implicit PUBLIC grants.
revoke all on function public.erp_has_role(uuid,text[]),public.erp_can_class(uuid,uuid),public.erp_can_student(uuid,uuid),
  public.erp_roster(uuid,uuid,uuid,integer),public.erp_sync_attendance(uuid,jsonb),public.erp_attendance_delta(uuid,text),
  public.erp_notices(uuid,uuid,text,integer),public.erp_notice_receipt(uuid,uuid,boolean),public.erp_publish_notice(uuid,text,text,boolean),
  public.erp_register_device(uuid,text,text),public.erp_unregister_device(text),public.erp_claim_notifications() from public,anon,authenticated;
grant execute on function public.erp_has_role(uuid,text[]),public.erp_can_class(uuid,uuid),public.erp_can_student(uuid,uuid),
  public.erp_roster(uuid,uuid,uuid,integer),public.erp_sync_attendance(uuid,jsonb),public.erp_attendance_delta(uuid,text),
  public.erp_notices(uuid,uuid,text,integer),public.erp_notice_receipt(uuid,uuid,boolean),public.erp_publish_notice(uuid,text,text,boolean),
  public.erp_register_device(uuid,text,text),public.erp_unregister_device(text) to authenticated;
grant execute on function public.erp_claim_notifications() to service_role;
grant all on public.erp_notification_outbox,public.erp_device_tokens,public.erp_guardians,public.erp_attendance,
  public.erp_notices,public.erp_notice_receipts,public.erp_students,public.erp_class_students,public.erp_class_teachers,public.erp_audit_events to service_role;
grant select on public.school_memberships to service_role;

drop policy content_authorized_read on public.school_content;
create policy content_authorized_read on public.school_content for select to authenticated using (
  public.erp_has_role(school_id,array['admin','principal']) or
  (public.erp_has_role(school_id,array['parent','teacher','student']) and
    (created_by=auth.uid() or visible_to @> array[auth.uid()] or (kind='class' and public.erp_can_class(school_id,id))))
);
create or replace function public.mobile_context() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare m public.school_memberships%rowtype; result jsonb; pair text[]; records jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into m from public.school_memberships where user_id=auth.uid() and active
    order by case role when 'admin' then 0 when 'principal' then 1 when 'teacher' then 2 when 'parent' then 3 else 4 end,id limit 1;
  result:=jsonb_build_object('school_id',m.school_id,'school_name',(select name from public.schools where id=m.school_id),
    'display_name',(select display_name from public.profiles where id=auth.uid()),'role',m.role);
  foreach pair slice 1 in array array[
    ['children','child'],['classes','class'],['homework','homework'],['worksheets','worksheet'],['timetable','timetable'],
    ['attendance','attendance'],['news','news'],['events','event'],['conversations','conversation'],['invoices','invoice'],['notifications','notification']
  ] loop
    select coalesce(jsonb_agg(r.payload order by r.created_at desc),'[]'::jsonb) into records from
      (select c.created_at,c.data||jsonb_build_object('id',c.id,'title',c.title,'description',c.description,'category',c.category,'status',c.status,'date',c.date) as payload
        from public.school_content c where c.school_id=m.school_id and c.kind=pair[2] order by c.created_at desc limit 100) r;
    result:=jsonb_set(result,array[pair[1]],records);
  end loop;
  if m.role in ('parent','student') then
    select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'title',s.name,'description',s.roll) order by s.id),'[]'::jsonb)
      into records from public.erp_students s where s.school_id=m.school_id;
    result:=jsonb_set(result,array['children'],records);
  end if;
  return result;
end;
$$;
commit;
