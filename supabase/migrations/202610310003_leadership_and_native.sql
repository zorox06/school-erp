-- Phase 3 contracts: erp_principal_summary, erp_audit_page, erp_action,
-- erp_read_conversation and service-only erp_alert_context. No seeded records.
begin;
create table public.erp_staff_attendance (
 school_id uuid not null references public.schools,user_id uuid not null references auth.users,
 day date not null,status text not null check(status in ('present','absent','leave')),
 updated_by uuid not null references auth.users,updated_at timestamptz not null default now(),primary key(school_id,user_id,day));
create table public.erp_emergencies (
 id uuid primary key,school_id uuid not null references public.schools,title text not null check(length(title) between 1 and 140),
 body text not null check(length(body) between 1 and 8000),created_by uuid not null references auth.users,created_at timestamptz not null default now());
create table public.erp_conversation_reads (
 school_id uuid not null references public.schools,conversation_id uuid not null references public.erp_conversations,user_id uuid not null references auth.users,
 read_at timestamptz not null default now(),primary key(conversation_id,user_id));
alter table public.erp_staff_attendance enable row level security;
alter table public.erp_emergencies enable row level security;
alter table public.erp_conversation_reads enable row level security;
revoke all on public.erp_staff_attendance,public.erp_emergencies,public.erp_conversation_reads from public,anon,authenticated;
grant select on public.erp_staff_attendance,public.erp_emergencies,public.erp_conversation_reads to authenticated;
grant all on public.erp_staff_attendance,public.erp_emergencies,public.erp_conversation_reads to service_role;
create policy staff_attendance_read on public.erp_staff_attendance for select to authenticated using(public.erp_has_role(school_id,array['principal','admin']) or (user_id=auth.uid() and public.erp_has_role(school_id,array['teacher'])));
create policy emergency_read on public.erp_emergencies for select to authenticated using(public.erp_has_role(school_id,array['parent','student','teacher','principal','admin']));
create policy conversation_reads_self on public.erp_conversation_reads for select to authenticated using(user_id=auth.uid() and public.erp_can_conversation(school_id,conversation_id));
create index audit_page_idx on public.erp_audit_events(school_id,id desc);
create index leave_status_idx on public.erp_leave_requests(school_id,status,created_at desc);
create index grades_school_student_idx on public.erp_grades(school_id,student_id);
create index guardian_user_idx on public.erp_guardians(user_id,school_id);
create index teacher_user_idx on public.erp_class_teachers(user_id,school_id);
create index assets_owner_idx on public.erp_assets(owner_id,school_id);

create function public.erp_principal_summary(p_school uuid,p_day date default current_date) returns jsonb language plpgsql security definer set search_path='' as $$
declare total bigint;recorded bigint;present bigint;absent_staff jsonb;staff_recorded bigint;staff_total bigint;pending bigint;
begin
 if not public.erp_has_role(p_school,array['admin','principal']) then raise exception 'Leadership access required' using errcode='42501';end if;
 select count(*) into total from public.erp_students where school_id=p_school;
 select count(*),count(*) filter(where status in ('present','late')) into recorded,present from public.erp_attendance where school_id=p_school and day=p_day;
 select count(distinct user_id) into staff_total from public.school_memberships where school_id=p_school and active and role='teacher';
 select count(*) into staff_recorded from public.erp_staff_attendance where school_id=p_school and day=p_day;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.user_id,'name',p.display_name,'status',a.status)),'[]'::jsonb) into absent_staff from public.erp_staff_attendance a left join public.profiles p on p.id=a.user_id where a.school_id=p_school and a.day=p_day and a.status in ('absent','leave');
 select count(*) into pending from public.erp_leave_requests where school_id=p_school and status='pending';
 return jsonb_build_object('day',p_day,'total_students',nullif(total,0),'recorded_students',nullif(recorded,0),'attendance_percent',case when recorded=0 then null else round(present*100.0/recorded,1) end,'coverage_percent',case when total=0 then null else round(recorded*100.0/total,1) end,'absent_teachers',absent_staff,'staff_recorded',nullif(staff_recorded,0),'staff_total',nullif(staff_total,0),'pending_leave',nullif(pending,0));
end $$;
create function public.erp_audit_page(p_school uuid,p_before bigint default null,p_limit integer default 40) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.erp_has_role(p_school,array['admin','principal']) then raise exception 'Leadership access required' using errcode='42501';end if;
 return(select coalesce(jsonb_agg(to_jsonb(r) order by r.id desc),'[]'::jsonb) from(select a.*,p.display_name as actor_name from public.erp_audit_events a left join public.profiles p on p.id=a.actor where a.school_id=p_school and (p_before is null or a.id<p_before) order by a.id desc limit greatest(1,least(coalesce(p_limit,40),100))) r);
end $$;
create function public.erp_read_conversation(p_school uuid,p_conversation uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.erp_can_conversation(p_school,p_conversation) then raise exception 'Conversation access denied' using errcode='42501';end if;
 insert into public.erp_conversation_reads values(p_school,p_conversation,auth.uid(),now()) on conflict(conversation_id,user_id) do update set read_at=excluded.read_at;
end $$;
create function public.erp_unread_counts(p_school uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) then raise exception 'School access required' using errcode='42501';end if;
 return(select coalesce(jsonb_object_agg(id,n),'{}'::jsonb) from(select c.id,count(m.id) n from public.erp_conversations c join public.erp_messages m on m.conversation_id=c.id left join public.erp_conversation_reads r on r.conversation_id=c.id and r.user_id=auth.uid() where c.school_id=p_school and public.erp_can_conversation(p_school,c.id) and m.sender_id<>auth.uid() and m.created_at>coalesce(r.read_at,'epoch'::timestamptz) group by c.id) x);
end $$;
create function public.erp_action(p_school uuid,p_kind text,p_operation uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare old public.erp_leave_requests%rowtype; saved public.erp_leave_requests%rowtype;result jsonb;target uuid;classroom uuid;staff uuid;d date;item uuid;recipient record;
begin
 if not public.erp_has_role(p_school,array['teacher','principal','admin']) then raise exception 'Staff access required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
 select o.result into result from public.erp_operations o where o.school_id=p_school and o.user_id=auth.uid() and o.operation_id=p_operation;
 if found then return result;end if;
 if p_kind='leave_decision' then
  target:=(p_payload->>'leave_id')::uuid;
  select * into old from public.erp_leave_requests where id=target and school_id=p_school;
  if old.id is null or not public.erp_can_student(p_school,old.student_id) then raise exception 'Leave access denied' using errcode='42501';end if;
  if p_payload->>'status' not in ('approved','denied') or p_payload->>'status' is null then raise exception 'Invalid decision' using errcode='22023';end if;
  if old.status<>'pending' or old.version<>coalesce((p_payload->>'expected_version')::integer,1) then
    result:=jsonb_build_object('conflict',true,'record',to_jsonb(old));
  else
    update public.erp_leave_requests set status=p_payload->>'status',version=version+1,decided_by=auth.uid() where id=target returning * into saved;
    insert into public.erp_audit_events(school_id,actor,action,entity_id,before_value,after_value) values(p_school,auth.uid(),'leave.decision',target::text,to_jsonb(old),to_jsonb(saved));
    insert into public.erp_notification_outbox(school_id,user_id,student_id,category,entity_id,dedupe_key) values(p_school,old.author_id,old.student_id,'leave',target,p_operation::text) on conflict(dedupe_key) do nothing;
    result:=jsonb_build_object('conflict',false,'record',to_jsonb(saved));
  end if;
 elsif p_kind='emergency' then
  if not public.erp_has_role(p_school,array['principal','admin']) then raise exception 'Leadership required' using errcode='42501';end if;
  insert into public.erp_emergencies values(p_operation,p_school,p_payload->>'title',p_payload->>'body',auth.uid(),now());
  insert into public.erp_notices(id,school_id,title,body,important,created_by) values(p_operation,p_school,p_payload->>'title',p_payload->>'body',true,auth.uid());
  insert into public.erp_notification_outbox(school_id,user_id,category,entity_id,dedupe_key) select distinct p_school,m.user_id,'emergency',p_operation,p_operation::text||':'||m.user_id::text from public.school_memberships m where m.school_id=p_school and m.active on conflict(dedupe_key) do nothing;
  insert into public.erp_audit_events(school_id,actor,action,entity_id,after_value) values(p_school,auth.uid(),'emergency.publish',p_operation::text,jsonb_build_object('title',p_payload->>'title'));
  result:=jsonb_build_object('conflict',false,'id',p_operation);
 elsif p_kind='timetable_change' then
  classroom:=(p_payload->>'class_id')::uuid;staff:=(p_payload->>'substitute_id')::uuid;
  if not public.erp_can_class(p_school,classroom) then raise exception 'Class access denied' using errcode='42501';end if;
  if staff is not null and (not public.erp_has_role(p_school,array['principal','admin']) or not exists(select 1 from public.school_memberships where school_id=p_school and user_id=staff and active and role='teacher')) then raise exception 'Substitute access denied' using errcode='42501';end if;
  if nullif(trim(p_payload->>'title'),'') is null or length(p_payload->>'title')>140 or (p_payload->>'date')::timestamptz is null then raise exception 'Title and date required' using errcode='22023';end if;
  item:=coalesce((p_payload->>'item_id')::uuid,p_operation);
  if exists(select 1 from public.school_content where id=item and (school_id<>p_school or kind<>'timetable' or data->>'class_id'<>classroom::text)) then raise exception 'Timetable access denied' using errcode='42501';end if;
  insert into public.school_content(id,school_id,kind,title,description,date,created_by,data) values(item,p_school,'timetable',p_payload->>'title',left(p_payload->>'description',4000),(p_payload->>'date')::timestamptz,auth.uid(),jsonb_build_object('class_id',classroom,'substitute_id',staff))
   on conflict(id) do update set title=excluded.title,description=excluded.description,date=excluded.date,data=excluded.data;
  if staff is not null then insert into public.erp_class_teachers values(p_school,classroom,staff) on conflict do nothing;end if;
  for recipient in select distinct user_id from(
   select t.user_id from public.erp_class_teachers t where t.school_id=p_school and t.class_id=classroom
   union select g.user_id from public.erp_guardians g join public.erp_class_students cs on cs.school_id=g.school_id and cs.student_id=g.student_id where cs.school_id=p_school and cs.class_id=classroom) x loop
    insert into public.erp_notification_outbox(school_id,user_id,category,entity_id,dedupe_key) values(p_school,recipient.user_id,'timetable',item,p_operation::text||':'||recipient.user_id::text) on conflict(dedupe_key) do nothing;
  end loop;
  insert into public.erp_audit_events(school_id,actor,action,entity_id,after_value) values(p_school,auth.uid(),'timetable.change',item::text,p_payload);
  result:=jsonb_build_object('conflict',false,'id',item);
 elsif p_kind='staff_attendance' then
  if not public.erp_has_role(p_school,array['principal','admin']) then raise exception 'Leadership required' using errcode='42501';end if;
  staff:=(p_payload->>'user_id')::uuid;d:=(p_payload->>'day')::date;
  if not exists(select 1 from public.school_memberships where school_id=p_school and user_id=staff and role='teacher' and active) or d is null then raise exception 'Teacher and day required' using errcode='22023';end if;
  insert into public.erp_staff_attendance values(p_school,staff,d,p_payload->>'status',auth.uid(),now()) on conflict(school_id,user_id,day) do update set status=excluded.status,updated_by=excluded.updated_by,updated_at=now();
  insert into public.erp_audit_events(school_id,actor,action,entity_id,after_value) values(p_school,auth.uid(),'staff.attendance',staff::text,p_payload);
  result:=jsonb_build_object('conflict',false);
 else raise exception 'Unknown action' using errcode='22023';end if;
 insert into public.erp_operations values(p_school,auth.uid(),p_operation,result,now());return result;
end $$;
create function public.erp_staff(p_school uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.erp_has_role(p_school,array['principal','admin']) then raise exception 'Leadership required' using errcode='42501';end if;
 return(select coalesce(jsonb_agg(jsonb_build_object('id',m.user_id,'name',p.display_name)),'[]'::jsonb) from public.school_memberships m left join public.profiles p on p.id=m.user_id where m.school_id=p_school and m.active and m.role='teacher');
end $$;
-- Wrap workspace to add unread counts, without changing its existing role/child filters.
alter function public.erp_workspace(uuid,uuid) rename to erp_workspace_v2;
create function public.erp_workspace(p_school uuid,p_child uuid default null) returns jsonb language sql security definer set search_path='' as $$
 select public.erp_workspace_v2(p_school,p_child)||jsonb_build_object('unread_counts',public.erp_unread_counts(p_school));
$$;
create function public.erp_alert_context(p_event uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.erp_notification_outbox%rowtype;p public.erp_notification_preferences%rowtype;valid boolean;zone text;minute integer;start_min integer;end_min integer;quiet boolean:=false;delay_at timestamptz;
begin
 select * into e from public.erp_notification_outbox where id=p_event;if not found then return jsonb_build_object('allowed',false);end if;
 valid:=exists(select 1 from public.school_memberships where school_id=e.school_id and user_id=e.user_id and active);
 if e.category='absence' then
  valid:=valid and exists(select 1 from public.erp_guardians g join public.erp_attendance a on a.student_id=g.student_id and a.school_id=g.school_id where g.school_id=e.school_id and g.user_id=e.user_id and a.student_id=e.student_id and a.day=e.attendance_day and a.status='absent' and a.operation_id=e.attendance_operation);
 elsif e.category='homework' then
  valid:=valid and exists(select 1 from public.erp_homework_classes hc join public.erp_class_students cs on cs.school_id=hc.school_id and cs.class_id=hc.class_id join public.erp_guardians g on g.school_id=cs.school_id and g.student_id=cs.student_id where hc.school_id=e.school_id and hc.homework_id=e.entity_id and g.user_id=e.user_id);
 elsif e.category='message' then
  valid:=valid and exists(select 1 from public.erp_messages m join public.erp_conversations c on c.id=m.conversation_id where m.id=e.entity_id and c.school_id=e.school_id and e.user_id in(c.staff_id,c.family_id));
 elsif e.category='leave' then
  valid:=valid and exists(select 1 from public.erp_leave_requests l where l.id=e.entity_id and l.school_id=e.school_id and (l.author_id=e.user_id or exists(select 1 from public.school_memberships m where m.school_id=e.school_id and m.user_id=e.user_id and m.active and m.role in ('principal','admin')) or exists(select 1 from public.erp_class_students cs join public.erp_class_teachers t on t.school_id=cs.school_id and t.class_id=cs.class_id where cs.school_id=e.school_id and cs.student_id=l.student_id and t.user_id=e.user_id)));
 end if;
 select * into p from public.erp_notification_preferences where school_id=e.school_id and user_id=e.user_id;
 if not found or not p.enabled or coalesce((p.categories->>e.category)::boolean,true)=false then return jsonb_build_object('allowed',valid,'muted',true);end if;
 zone:=p.timezone;minute:=extract(hour from now() at time zone zone)::integer*60+extract(minute from now() at time zone zone)::integer;
 start_min:=p.quiet_start;end_min:=p.quiet_end;
 if p.quiet_enabled and e.category not in ('absence','emergency') then quiet:=case when start_min<end_min then minute>=start_min and minute<end_min when start_min>end_min then minute>=start_min or minute<end_min else false end;end if;
 if e.category='message' and p.teacher_quiet_enabled then
  if (case when p.teacher_quiet_start<p.teacher_quiet_end then minute>=p.teacher_quiet_start and minute<p.teacher_quiet_end when p.teacher_quiet_start>p.teacher_quiet_end then minute>=p.teacher_quiet_start or minute<p.teacher_quiet_end else false end) then
   quiet:=true;end_min:=p.teacher_quiet_end;
  end if;
 end if;
 if quiet then delay_at:=(((now() at time zone zone)::date+case when minute>=end_min then 1 else 0 end)+make_interval(mins=>end_min)) at time zone zone;end if;
 return jsonb_build_object('allowed',valid,'muted',false,'defer_until',delay_at,'school_id',e.school_id,'entity_id',e.entity_id);
end $$;
do $$ declare r record;begin
 for r in select oid::regprocedure signature from pg_proc where pronamespace='public'::regnamespace and proname in ('erp_principal_summary','erp_audit_page','erp_read_conversation','erp_unread_counts','erp_action','erp_staff','erp_workspace','erp_workspace_v2') loop
 execute format('revoke all on function %s from public,anon,authenticated',r.signature);execute format('grant execute on function %s to authenticated',r.signature);end loop;
end $$;
revoke all on function public.erp_alert_context(uuid) from public,anon,authenticated;
grant execute on function public.erp_alert_context(uuid) to service_role;
commit;
