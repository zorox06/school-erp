-- Phase 2: normalized, empty learning/messaging/assessment contracts.
begin;
create table public.erp_assets (
  id uuid primary key,school_id uuid not null references public.schools,owner_id uuid not null references auth.users,
  kind text not null check(kind in ('homework','worksheet','submission')),linked_id uuid,
  path text not null unique,mime text not null check(mime in ('image/jpeg','image/png','application/pdf')),
  bytes integer not null check(bytes between 1 and 10485760),ready boolean not null default false,created_at timestamptz not null default now()
);
create table public.erp_homework (
  id uuid primary key,school_id uuid not null references public.schools,author_id uuid not null references auth.users,
  kind text not null check(kind in ('homework','worksheet')),title text not null check(length(btrim(title)) between 1 and 140),
  body text not null default '' check(length(body)<=8000),due_at timestamptz,asset_ids uuid[] not null default '{}',
  created_at timestamptz not null default now()
);
create table public.erp_homework_classes (
  school_id uuid not null references public.schools,homework_id uuid not null references public.erp_homework,
  class_id uuid not null references public.school_content,primary key(homework_id,class_id)
);
create table public.erp_submissions (
  id uuid primary key,school_id uuid not null references public.schools,homework_id uuid not null references public.erp_homework,
  student_id uuid not null references public.erp_students,author_id uuid not null references auth.users,
  body text not null default '' check(length(body)<=8000),asset_ids uuid[] not null default '{}',
  submitted_at timestamptz not null default now(),feedback text,unique(homework_id,student_id)
);
create table public.erp_conversations (
  id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools,
  student_id uuid not null references public.erp_students,staff_id uuid not null references auth.users,
  family_id uuid not null references auth.users,created_at timestamptz not null default now(),
  unique(school_id,student_id,staff_id,family_id),check(staff_id<>family_id)
);
create table public.erp_messages (
  id uuid primary key,school_id uuid not null references public.schools,conversation_id uuid not null references public.erp_conversations,
  sender_id uuid not null references auth.users,body text not null check(length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index erp_messages_page_idx on public.erp_messages(conversation_id,created_at desc,id desc);
create table public.erp_assessments (
  id uuid primary key,school_id uuid not null references public.schools,class_id uuid not null references public.school_content,
  subject text not null check(length(btrim(subject)) between 1 and 80),title text not null check(length(btrim(title)) between 1 and 140),
  max_score numeric not null check(max_score>0 and max_score<=10000),exam_at timestamptz not null,
  created_by uuid not null references auth.users,created_at timestamptz not null default now()
);
create table public.erp_grades (
  id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools,
  assessment_id uuid not null references public.erp_assessments,student_id uuid not null references public.erp_students,
  score numeric not null check(score>=0),version integer not null default 1,updated_by uuid not null references auth.users,
  updated_at timestamptz not null default now(),unique(assessment_id,student_id)
);
create table public.erp_leave_requests (
  id uuid primary key,school_id uuid not null references public.schools,student_id uuid not null references public.erp_students,
  author_id uuid not null references auth.users,starts_on date not null,ends_on date not null,
  reason text not null check(length(btrim(reason)) between 1 and 2000),status text not null default 'pending' check(status in ('pending','approved','denied')),
  version integer not null default 1,decided_by uuid references auth.users,created_at timestamptz not null default now(),
  check(ends_on>=starts_on and ends_on<=starts_on+366)
);
create table public.erp_notification_preferences (
  school_id uuid not null references public.schools,user_id uuid not null references auth.users,
  enabled boolean not null default false,categories jsonb not null default '{"absence":true,"emergency":true,"notice":true,"homework":true,"message":true,"timetable":true,"leave":true}',
  quiet_enabled boolean not null default false,quiet_start integer not null default 1200 check(quiet_start between 0 and 1439),
  quiet_end integer not null default 420 check(quiet_end between 0 and 1439),timezone text not null default 'UTC',
  teacher_quiet_enabled boolean not null default false,teacher_quiet_start integer not null default 1080 check(teacher_quiet_start between 0 and 1439),
  teacher_quiet_end integer not null default 480 check(teacher_quiet_end between 0 and 1439),primary key(school_id,user_id)
);
create table public.erp_operations (
  school_id uuid not null references public.schools,user_id uuid not null references auth.users,
  operation_id uuid not null,result jsonb not null,created_at timestamptz not null default now(),primary key(school_id,user_id,operation_id)
);
alter table public.erp_notification_outbox drop constraint erp_notification_outbox_category_check;
alter table public.erp_notification_outbox add constraint erp_notification_outbox_category_check check(category in ('absence','notice','homework','message','leave','timetable','emergency'));
alter table public.erp_notification_outbox add column entity_id uuid;

create function public.erp_child_in_class(p_school uuid,p_child uuid,p_class uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.erp_can_student(p_school,p_child) and exists(select 1 from public.erp_class_students cs
    where cs.school_id=p_school and cs.student_id=p_child and cs.class_id=p_class);
$$;
create function public.erp_can_homework(p_school uuid,p_homework uuid,p_child uuid default null) returns boolean
language sql stable security definer set search_path='' as $$
  select public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) and exists(
    select 1 from public.erp_homework_classes hc where hc.school_id=p_school and hc.homework_id=p_homework and
      ((public.erp_has_role(p_school,array['admin','principal','teacher']) and public.erp_can_class(p_school,hc.class_id)) or
       (public.erp_has_role(p_school,array['parent','student']) and
         ((p_child is not null and public.erp_child_in_class(p_school,p_child,hc.class_id)) or
          (p_child is null and exists(select 1 from public.erp_class_students cs where cs.school_id=p_school and cs.class_id=hc.class_id and public.erp_can_student(p_school,cs.student_id)))))));
$$;
create function public.erp_can_conversation(p_school uuid,p_conversation uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) and exists(
    select 1 from public.erp_conversations c where c.school_id=p_school and c.id=p_conversation
      and auth.uid() in(c.staff_id,c.family_id) and public.erp_can_student(p_school,c.student_id));
$$;
create function public.erp_can_asset(p_asset uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.erp_assets a where a.id=p_asset and a.ready and
    (a.owner_id=auth.uid() and public.erp_has_role(a.school_id,array['admin','principal','teacher','parent','student'])
      or exists(select 1 from public.erp_homework h where a.id=any(h.asset_ids) and h.school_id=a.school_id and public.erp_can_homework(h.school_id,h.id))
      or exists(select 1 from public.erp_submissions s where a.id=any(s.asset_ids) and s.school_id=a.school_id and public.erp_can_student(s.school_id,s.student_id) and public.erp_can_homework(s.school_id,s.homework_id))));
$$;

do $$ declare t text; begin
  foreach t in array array['erp_assets','erp_homework','erp_homework_classes','erp_submissions','erp_conversations','erp_messages','erp_assessments','erp_grades','erp_leave_requests','erp_notification_preferences','erp_operations'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from anon,authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
  end loop;
end $$;
create policy asset_authorized on public.erp_assets for select to authenticated using(public.erp_can_asset(id) or (owner_id=auth.uid() and public.erp_has_role(school_id,array['admin','principal','teacher','parent','student'])));
create policy homework_authorized on public.erp_homework for select to authenticated using(public.erp_can_homework(school_id,id));
create policy homework_classes_authorized on public.erp_homework_classes for select to authenticated using(public.erp_can_homework(school_id,homework_id));
create policy submissions_authorized on public.erp_submissions for select to authenticated using(public.erp_can_student(school_id,student_id) and public.erp_can_homework(school_id,homework_id));
create policy conversations_participant on public.erp_conversations for select to authenticated using(public.erp_can_conversation(school_id,id));
create policy messages_participant on public.erp_messages for select to authenticated using(public.erp_can_conversation(school_id,conversation_id));
create policy assessments_authorized on public.erp_assessments for select to authenticated using(public.erp_can_class(school_id,class_id) or (public.erp_has_role(school_id,array['parent','student']) and exists(select 1 from public.erp_class_students cs where cs.school_id=erp_assessments.school_id and cs.class_id=erp_assessments.class_id and public.erp_can_student(cs.school_id,cs.student_id))));
create policy grades_authorized on public.erp_grades for select to authenticated using(public.erp_can_student(school_id,student_id) and exists(select 1 from public.erp_assessments a where a.id=assessment_id and a.school_id=erp_grades.school_id and (public.erp_can_class(a.school_id,a.class_id) or public.erp_has_role(a.school_id,array['parent','student']))));
create policy leaves_authorized on public.erp_leave_requests for select to authenticated using(public.erp_can_student(school_id,student_id));
create policy preferences_self on public.erp_notification_preferences for select to authenticated using(user_id=auth.uid() and public.erp_has_role(school_id,array['admin','principal','teacher','parent','student']));
create policy operations_self on public.erp_operations for select to authenticated using(user_id=auth.uid());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  values('school-files','school-files',false,10485760,array['image/jpeg','image/png','application/pdf'])
  on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy school_asset_upload on storage.objects for insert to authenticated with check(bucket_id='school-files' and exists(
  select 1 from public.erp_assets a where a.path=name and a.owner_id=auth.uid() and not a.ready and public.erp_has_role(a.school_id,array['admin','principal','teacher','parent','student'])));
create policy school_asset_read on storage.objects for select to authenticated using(bucket_id='school-files' and exists(
  select 1 from public.erp_assets a where a.path=name and (public.erp_can_asset(a.id) or (a.owner_id=auth.uid() and public.erp_has_role(a.school_id,array['admin','principal','teacher','parent','student'])))));

create function public.erp_reserve_asset(p_school uuid,p_asset uuid,p_kind text,p_linked uuid,p_mime text,p_bytes integer) returns text
language plpgsql security definer set search_path='' as $$
declare destination text; prior public.erp_assets%rowtype;
begin
  if p_kind in ('homework','worksheet') then
    if not public.erp_can_class(p_school,p_linked) then raise exception 'Class access denied' using errcode='42501'; end if;
  elsif p_kind='submission' then
    if not public.erp_has_role(p_school,array['parent','student']) or not public.erp_can_homework(p_school,p_linked) then raise exception 'Submission access denied' using errcode='42501'; end if;
  else raise exception 'Unsupported asset context' using errcode='22023'; end if;
  if p_mime not in ('image/jpeg','image/png','application/pdf') or p_bytes not between 1 and 10485760 then raise exception 'Unsupported file' using errcode='22023'; end if;
  destination:=p_school::text||'/'||auth.uid()::text||'/'||p_asset::text||case p_mime when 'image/jpeg' then '.jpg' when 'image/png' then '.png' else '.pdf' end;
  select * into prior from public.erp_assets where id=p_asset;
  if prior.id is not null then
    if prior.owner_id<>auth.uid() or prior.school_id<>p_school or prior.kind<>p_kind or prior.linked_id<>p_linked or prior.bytes<>p_bytes or prior.mime<>p_mime then raise exception 'Asset identity mismatch' using errcode='42501'; end if;
    return prior.path;
  end if;
  insert into public.erp_assets(id,school_id,owner_id,kind,linked_id,path,mime,bytes) values(p_asset,p_school,auth.uid(),p_kind,p_linked,destination,p_mime,p_bytes);
  return destination;
end;
$$;
create function public.erp_finish_asset(p_school uuid,p_asset uuid) returns void
language plpgsql security definer set search_path='' as $$
declare a public.erp_assets%rowtype; obj jsonb;
begin
  select * into a from public.erp_assets where id=p_asset and school_id=p_school and owner_id=auth.uid();
  if a.id is null or not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) then raise exception 'Asset access denied' using errcode='42501'; end if;
  select metadata into obj from storage.objects where bucket_id='school-files' and name=a.path;
  if obj is null or (obj->>'size')::bigint<>a.bytes or obj->>'mimetype'<>a.mime then raise exception 'Upload is incomplete or mismatched' using errcode='22023'; end if;
  update public.erp_assets set ready=true where id=a.id;
end;
$$;
create function public.erp_asset_access(p_school uuid,p_asset uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if not public.erp_can_asset(p_asset) then raise exception 'Asset access denied' using errcode='42501'; end if;
  return (select jsonb_build_object('id',id,'path',path,'mime',mime,'bytes',bytes) from public.erp_assets where id=p_asset and school_id=p_school);
end;
$$;

create function public.erp_contacts(p_school uuid,p_child uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) or (p_child is not null and not public.erp_can_student(p_school,p_child)) then raise exception 'School/child access denied' using errcode='42501'; end if;
  if public.erp_has_role(p_school,array['admin','principal','teacher']) then
    return (select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from (select distinct g.user_id as id,g.student_id,s.name as student_name,p.display_name as name,
      pref.teacher_quiet_enabled,pref.teacher_quiet_start,pref.teacher_quiet_end,pref.timezone
      from public.erp_guardians g join public.erp_students s on s.id=g.student_id and s.school_id=g.school_id
      left join public.profiles p on p.id=g.user_id left join public.erp_notification_preferences pref on pref.school_id=p_school and pref.user_id=g.user_id
      where g.school_id=p_school and public.erp_can_student(p_school,g.student_id) and (p_child is null or g.student_id=p_child)
      and exists(select 1 from public.school_memberships m where m.school_id=p_school and m.user_id=g.user_id and m.active and m.role='parent') limit 200) r);
  end if;
  if p_child is null then return '[]'::jsonb; end if;
  return (select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from (select distinct t.user_id as id,p_child as student_id,s.name as student_name,p.display_name as name,
    pref.teacher_quiet_enabled,pref.teacher_quiet_start,pref.teacher_quiet_end,pref.timezone
    from public.erp_class_teachers t join public.erp_class_students cs on cs.school_id=t.school_id and cs.class_id=t.class_id
    join public.erp_students s on s.id=cs.student_id and s.school_id=cs.school_id left join public.profiles p on p.id=t.user_id
    left join public.erp_notification_preferences pref on pref.school_id=p_school and pref.user_id=t.user_id
    where cs.school_id=p_school and cs.student_id=p_child and exists(select 1 from public.school_memberships m
      where m.school_id=p_school and m.user_id=t.user_id and m.active and m.role='teacher') limit 200) r);
end;
$$;
create function public.erp_learning_page(p_school uuid,p_child uuid default null,p_kind text default 'homework',p_after text default null,p_limit integer default 30) returns jsonb
language plpgsql security definer set search_path='' as $$
declare stamp timestamptz; last_id uuid;
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) or (p_child is not null and not public.erp_can_student(p_school,p_child)) then raise exception 'School/child access denied' using errcode='42501'; end if;
  if p_child is null and not public.erp_has_role(p_school,array['admin','principal','teacher']) then return '[]'::jsonb; end if;
  if p_after is not null then stamp:=split_part(p_after,'|',1)::timestamptz;last_id:=split_part(p_after,'|',2)::uuid;end if;
  return (select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id desc),'[]'::jsonb) from
    (select h.*, (select jsonb_agg(c.class_id) from public.erp_homework_classes c where c.homework_id=h.id) as class_ids,
      (select to_jsonb(s) from public.erp_submissions s where s.homework_id=h.id and s.student_id=p_child) as submission
    from public.erp_homework h where h.school_id=p_school and h.kind=p_kind and public.erp_can_homework(p_school,h.id,p_child)
      and (p_after is null or (h.created_at,h.id)<(stamp,last_id)) order by h.created_at desc,h.id desc limit greatest(1,least(p_limit,100))) r);
end;
$$;
create function public.erp_messages_page(p_school uuid,p_conversation uuid,p_after text default null,p_limit integer default 40) returns jsonb
language plpgsql security definer set search_path='' as $$
declare stamp timestamptz;last_id uuid;
begin
  if not public.erp_can_conversation(p_school,p_conversation) then raise exception 'Conversation access denied' using errcode='42501';end if;
  if p_after is not null then stamp:=split_part(p_after,'|',1)::timestamptz;last_id:=split_part(p_after,'|',2)::uuid;end if;
  return (select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id desc),'[]'::jsonb) from
    (select m.id,m.sender_id,m.body,m.created_at from public.erp_messages m where m.school_id=p_school and m.conversation_id=p_conversation
      and (p_after is null or (m.created_at,m.id)<(stamp,last_id)) order by m.created_at desc,m.id desc limit greatest(1,least(p_limit,100))) r);
end;
$$;

create function public.erp_workspace(p_school uuid,p_child uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; staff boolean; records jsonb;
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) or (p_child is not null and not public.erp_can_student(p_school,p_child)) then raise exception 'School/child access denied' using errcode='42501'; end if;
  staff:=public.erp_has_role(p_school,array['admin','principal','teacher']);
  result:=jsonb_build_object('homework',public.erp_learning_page(p_school,p_child,'homework'),'worksheets',public.erp_learning_page(p_school,p_child,'worksheet'),'contacts',public.erp_contacts(p_school,p_child));
  select coalesce(jsonb_agg(to_jsonb(r) order by r.exam_at),'[]'::jsonb) into records from
    (select a.* from public.erp_assessments a where a.school_id=p_school and ((staff and public.erp_can_class(p_school,a.class_id))
      or (p_child is not null and public.erp_child_in_class(p_school,p_child,a.class_id))) order by a.exam_at desc limit 200) r;
  result:=result||jsonb_build_object('assessments',records);
  select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) into records from
    (select g.*,a.title,a.subject,a.exam_at,a.max_score,a.class_id from public.erp_grades g join public.erp_assessments a on a.id=g.assessment_id
      where g.school_id=p_school and ((staff and public.erp_can_class(p_school,a.class_id)) or (p_child is not null and g.student_id=p_child)) limit 1000) r;
  result:=result||jsonb_build_object('grades',records);
  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]'::jsonb) into records from
    (select c.*,s.name as student_name,p.display_name as contact_name from public.erp_conversations c join public.erp_students s on s.id=c.student_id
      left join public.profiles p on p.id=case when c.staff_id=auth.uid() then c.family_id else c.staff_id end
      where c.school_id=p_school and public.erp_can_conversation(p_school,c.id) and (staff or c.student_id=p_child) order by c.created_at desc limit 100) r;
  result:=result||jsonb_build_object('conversations',records);
  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]'::jsonb) into records from
    (select l.*,s.name as student_name from public.erp_leave_requests l join public.erp_students s on s.id=l.student_id where l.school_id=p_school
      and ((staff and public.erp_can_student(p_school,l.student_id)) or (p_child is not null and l.student_id=p_child)) order by l.created_at desc limit 100) r;
  result:=result||jsonb_build_object('leaves',records);
  select coalesce(jsonb_agg(to_jsonb(r) order by r.submitted_at desc),'[]'::jsonb) into records from
    (select s.*,st.name as student_name from public.erp_submissions s join public.erp_students st on st.id=s.student_id
      where s.school_id=p_school and ((staff and public.erp_can_homework(p_school,s.homework_id) and public.erp_can_student(p_school,s.student_id))
        or (p_child is not null and s.student_id=p_child)) order by s.submitted_at desc limit 100) r;
  result:=result||jsonb_build_object('submissions',records);
  -- A timetable item must declare class_id or school_wide=true, never infer an audience.
  select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) into records from
    (select c.id,c.title,c.description,c.date,c.data from public.school_content c where c.school_id=p_school and c.kind='timetable'
      and (c.data->>'school_wide'='true' or (c.data->>'class_id' is not null and
        ((staff and public.erp_can_class(p_school,(c.data->>'class_id')::uuid)) or (p_child is not null and public.erp_child_in_class(p_school,p_child,(c.data->>'class_id')::uuid))))) limit 200) r;
  result:=result||jsonb_build_object('timetable',records,'preferences',coalesce((select to_jsonb(p) from public.erp_notification_preferences p where p.school_id=p_school and p.user_id=auth.uid()),'{}'::jsonb));
  return result;
end;
$$;

create function public.erp_write(p_school uuid,p_kind text,p_operation uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; classroom uuid; student uuid; linked uuid; target uuid; item uuid;
  asset uuid; assets uuid[]:='{}'; staff boolean; a public.erp_assessments%rowtype; g public.erp_grades%rowtype;
  old_grade public.erp_grades%rowtype; conv public.erp_conversations%rowtype; contact jsonb; expected integer; score_value numeric;
begin
  if auth.uid() is null or not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) then raise exception 'School access denied' using errcode='42501';end if;
  if p_operation is null or p_payload is null or length(p_payload::text)>24000 then raise exception 'Invalid operation' using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
  select o.result into result from public.erp_operations o where o.school_id=p_school and o.user_id=auth.uid() and o.operation_id=p_operation;
  if result is not null then return result;end if;
  staff:=public.erp_has_role(p_school,array['admin','principal','teacher']);
  if p_payload ? 'asset_ids' then
    if jsonb_typeof(p_payload->'asset_ids')<>'array' or jsonb_array_length(p_payload->'asset_ids')>5 then raise exception 'Too many attachments' using errcode='22023';end if;
    for asset in select value::uuid from jsonb_array_elements_text(p_payload->'asset_ids') loop
      if not exists(select 1 from public.erp_assets x where x.id=asset and x.school_id=p_school and x.owner_id=auth.uid() and x.ready) then raise exception 'Attachment access denied' using errcode='42501';end if;
      assets:=array_append(assets,asset);
    end loop;
  end if;
  if p_kind in ('homework','worksheet') then
    if not staff then raise exception 'Staff access required' using errcode='42501';end if;
    if jsonb_typeof(p_payload->'class_ids')<>'array' or coalesce(jsonb_array_length(p_payload->'class_ids'),0) not between 1 and 30 then raise exception 'Select assigned classes' using errcode='22023';end if;
    if p_kind='homework' and p_payload->>'due_at' is null then raise exception 'Due date required' using errcode='22023';end if;
    for classroom in select value::uuid from jsonb_array_elements_text(p_payload->'class_ids') loop
      if not public.erp_can_class(p_school,classroom) then raise exception 'Class access denied' using errcode='42501';end if;
    end loop;
    insert into public.erp_homework(id,school_id,author_id,kind,title,body,due_at,asset_ids)
      values(p_operation,p_school,auth.uid(),p_kind,p_payload->>'title',coalesce(p_payload->>'body',''),(p_payload->>'due_at')::timestamptz,assets);
    insert into public.erp_homework_classes select p_school,p_operation,value::uuid from jsonb_array_elements_text(p_payload->'class_ids') on conflict do nothing;
    insert into public.erp_notification_outbox(school_id,user_id,category,entity_id,dedupe_key)
      select distinct p_school,gu.user_id,'homework',p_operation,p_operation::text||':'||gu.user_id::text from public.erp_homework_classes hc
        join public.erp_class_students cs on cs.school_id=p_school and cs.class_id=hc.class_id
        join public.erp_guardians gu on gu.school_id=p_school and gu.student_id=cs.student_id where hc.homework_id=p_operation on conflict(dedupe_key) do nothing;
    result:=jsonb_build_object('id',p_operation,'conflict',false);
  elsif p_kind='submission' then
    student:=(p_payload->>'student_id')::uuid;linked:=(p_payload->>'homework_id')::uuid;
    if not public.erp_has_role(p_school,array['parent','student']) or not public.erp_can_student(p_school,student) or not public.erp_can_homework(p_school,linked,student) then raise exception 'Submission access denied' using errcode='42501';end if;
    if cardinality(assets)=0 then raise exception 'Attach completed work' using errcode='22023';end if;
    insert into public.erp_submissions(id,school_id,homework_id,student_id,author_id,body,asset_ids)
      values(p_operation,p_school,linked,student,auth.uid(),coalesce(p_payload->>'body',''),assets)
      on conflict(homework_id,student_id) do update set body=excluded.body,asset_ids=excluded.asset_ids,submitted_at=now(),author_id=auth.uid(),feedback=null returning id into item;
    result:=jsonb_build_object('id',item,'conflict',false);
  elsif p_kind='feedback' then
    target:=(p_payload->>'submission_id')::uuid;
    if not staff or not exists(select 1 from public.erp_submissions s where s.id=target and s.school_id=p_school and public.erp_can_homework(p_school,s.homework_id) and public.erp_can_student(p_school,s.student_id)) then raise exception 'Review access denied' using errcode='42501';end if;
    if length(coalesce(p_payload->>'feedback',''))>4000 then raise exception 'Feedback too long' using errcode='22023';end if;
    update public.erp_submissions set feedback=p_payload->>'feedback' where id=target;
    result:=jsonb_build_object('id',target,'conflict',false);
  elsif p_kind='message' then
    linked:=(p_payload->>'conversation_id')::uuid;
    if linked is null then
      student:=(p_payload->>'student_id')::uuid;target:=(p_payload->>'contact_id')::uuid;
      if student is null or target is null or not public.erp_can_student(p_school,student) then raise exception 'Contact access denied' using errcode='42501';end if;
      if not exists(select 1 from jsonb_array_elements(public.erp_contacts(p_school,student)) x where (x->>'id')::uuid=target and (x->>'student_id')::uuid=student) then raise exception 'Approved contact required' using errcode='42501';end if;
      insert into public.erp_conversations(school_id,student_id,staff_id,family_id) values(p_school,student,case when staff then auth.uid() else target end,case when staff then target else auth.uid() end)
        on conflict(school_id,student_id,staff_id,family_id) do update set student_id=excluded.student_id returning id into linked;
    end if;
    if not public.erp_can_conversation(p_school,linked) then raise exception 'Conversation access denied' using errcode='42501';end if;
    insert into public.erp_messages(id,school_id,conversation_id,sender_id,body) values(p_operation,p_school,linked,auth.uid(),p_payload->>'body');
    select * into conv from public.erp_conversations where id=linked;
    insert into public.erp_notification_outbox(school_id,user_id,category,entity_id,dedupe_key) values(p_school,case when conv.staff_id=auth.uid() then conv.family_id else conv.staff_id end,'message',p_operation,p_operation::text) on conflict(dedupe_key) do nothing;
    result:=jsonb_build_object('id',p_operation,'conversation_id',linked,'conflict',false);
  elsif p_kind='assessment' then
    classroom:=(p_payload->>'class_id')::uuid;
    if not staff or not public.erp_can_class(p_school,classroom) then raise exception 'Assessment access denied' using errcode='42501';end if;
    insert into public.erp_assessments(id,school_id,class_id,subject,title,max_score,exam_at,created_by) values(p_operation,p_school,classroom,p_payload->>'subject',p_payload->>'title',(p_payload->>'max_score')::numeric,(p_payload->>'exam_at')::timestamptz,auth.uid());
    result:=jsonb_build_object('id',p_operation,'conflict',false);
  elsif p_kind='grade' then
    linked:=(p_payload->>'assessment_id')::uuid;student:=(p_payload->>'student_id')::uuid;
    select * into a from public.erp_assessments where id=linked and school_id=p_school;
    if not staff or a.id is null or not public.erp_can_class(p_school,a.class_id) or not exists(select 1 from public.erp_class_students cs where cs.school_id=p_school and cs.class_id=a.class_id and cs.student_id=student) then raise exception 'Grade access denied' using errcode='42501';end if;
    expected:=coalesce((p_payload->>'expected_version')::integer,0);score_value:=(p_payload->>'score')::numeric;
    if score_value is null or score_value<0 or score_value>a.max_score then raise exception 'Score out of range' using errcode='22023';end if;
    select * into old_grade from public.erp_grades where assessment_id=linked and student_id=student;
    if coalesce(old_grade.version,0)<>expected then
      result:=jsonb_build_object('id',old_grade.id,'conflict',true,'record',to_jsonb(old_grade));
    else
      insert into public.erp_grades(school_id,assessment_id,student_id,score,updated_by) values(p_school,linked,student,score_value,auth.uid())
        on conflict(assessment_id,student_id) do update set score=excluded.score,version=erp_grades.version+1,updated_by=auth.uid(),updated_at=now() returning * into g;
      insert into public.erp_audit_events(school_id,actor,action,entity_id,before_value,after_value) values(p_school,auth.uid(),'grade.edit',g.id::text,case when old_grade.id is null then null else to_jsonb(old_grade) end,to_jsonb(g));
      result:=jsonb_build_object('id',g.id,'conflict',false,'record',to_jsonb(g));
    end if;
  elsif p_kind='leave' then
    student:=(p_payload->>'student_id')::uuid;
    if not public.erp_has_role(p_school,array['parent']) or not public.erp_can_student(p_school,student) then raise exception 'Leave access denied' using errcode='42501';end if;
    insert into public.erp_leave_requests(id,school_id,student_id,author_id,starts_on,ends_on,reason) values(p_operation,p_school,student,auth.uid(),(p_payload->>'starts_on')::date,(p_payload->>'ends_on')::date,p_payload->>'reason');
    insert into public.erp_notification_outbox(school_id,user_id,category,entity_id,dedupe_key)
      select distinct p_school,t.user_id,'leave',p_operation,p_operation::text||':'||t.user_id::text from public.erp_class_students cs join public.erp_class_teachers t
        on t.school_id=cs.school_id and t.class_id=cs.class_id where cs.school_id=p_school and cs.student_id=student on conflict(dedupe_key) do nothing;
    result:=jsonb_build_object('id',p_operation,'conflict',false);
  else raise exception 'Unknown operation' using errcode='22023';end if;
  insert into public.erp_operations(school_id,user_id,operation_id,result) values(p_school,auth.uid(),p_operation,result);
  return result;
end;
$$;

create function public.erp_save_preferences(p_school uuid,p_preferences jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare zone text:=coalesce(p_preferences->>'timezone','UTC');
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) then raise exception 'School access denied' using errcode='42501';end if;
  if not exists(select 1 from pg_timezone_names where name=zone) or jsonb_typeof(coalesce(p_preferences->'categories','{}'::jsonb))<>'object' then raise exception 'Invalid preferences' using errcode='22023';end if;
  insert into public.erp_notification_preferences(school_id,user_id,enabled,categories,quiet_enabled,quiet_start,quiet_end,timezone,teacher_quiet_enabled,teacher_quiet_start,teacher_quiet_end)
    values(p_school,auth.uid(),coalesce((p_preferences->>'enabled')::boolean,false),coalesce(p_preferences->'categories','{}'::jsonb),
      coalesce((p_preferences->>'quiet_enabled')::boolean,false),coalesce((p_preferences->>'quiet_start')::integer,1200),coalesce((p_preferences->>'quiet_end')::integer,420),zone,
      coalesce((p_preferences->>'teacher_quiet_enabled')::boolean,false),coalesce((p_preferences->>'teacher_quiet_start')::integer,1080),coalesce((p_preferences->>'teacher_quiet_end')::integer,480))
    on conflict(school_id,user_id) do update set enabled=excluded.enabled,categories=excluded.categories,quiet_enabled=excluded.quiet_enabled,
      quiet_start=excluded.quiet_start,quiet_end=excluded.quiet_end,timezone=excluded.timezone,teacher_quiet_enabled=excluded.teacher_quiet_enabled,
      teacher_quiet_start=excluded.teacher_quiet_start,teacher_quiet_end=excluded.teacher_quiet_end;
end;
$$;
do $$ declare p record;begin
  for p in select oid::regprocedure as signature from pg_proc where pronamespace='public'::regnamespace and proname in
    ('erp_child_in_class','erp_can_homework','erp_can_conversation','erp_can_asset','erp_reserve_asset','erp_finish_asset','erp_asset_access','erp_contacts','erp_learning_page','erp_messages_page','erp_workspace','erp_write','erp_save_preferences') loop
    execute format('revoke all on function %s from public,anon,authenticated',p.signature);
    execute format('grant execute on function %s to authenticated',p.signature);
  end loop;
end $$;
grant all on public.erp_notification_preferences,public.erp_conversations,public.erp_messages,public.erp_homework,public.erp_homework_classes,public.erp_leave_requests to service_role;
-- Existing event-trigger helper need not be callable through the app API.
do $$ begin if to_regprocedure('public.rls_auto_enable()') is not null then
  revoke execute on function public.rls_auto_enable() from public,anon,authenticated;
end if;end $$;
commit;
