begin;
-- Retain the original teacher and period duration when assigning cover.
create or replace function public.erp_action(p_school uuid,p_kind text,p_operation uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
  if exists(select 1 from public.school_content where id=item and (school_id<>p_school or kind<>'timetable' or coalesce(data->>'class_id','')<>classroom::text)) then raise exception 'Timetable access denied' using errcode='42501';end if;
  insert into public.school_content(id,school_id,kind,title,description,date,created_by,data) values(item,p_school,'timetable',p_payload->>'title',left(p_payload->>'description',4000),(p_payload->>'date')::timestamptz,auth.uid(),jsonb_build_object('class_id',classroom,'substitute_id',staff))
   on conflict(id) do update set title=excluded.title,description=excluded.description,date=excluded.date,data=coalesce(school_content.data,'{}'::jsonb) || excluded.data;

  for recipient in select distinct user_id from(
   select t.user_id from public.erp_class_teachers t where t.school_id=p_school and t.class_id=classroom
   union select staff where staff is not null
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

create or replace function public.erp_principal_summary(p_school uuid,p_day date default current_date) returns jsonb language plpgsql security definer set search_path='' as $$
declare total bigint;recorded bigint;present bigint;absent_staff jsonb;staff_recorded bigint;staff_total bigint;pending bigint; unmarked jsonb;
begin
 if not public.erp_has_role(p_school,array['admin','principal']) then raise exception 'Leadership access required' using errcode='42501';end if;
 select count(*) into total from public.erp_students where school_id=p_school;
 select count(*),count(*) filter(where status in ('present','late')) into recorded,present from public.erp_attendance where school_id=p_school and day=p_day;
 select count(distinct user_id) into staff_total from public.school_memberships where school_id=p_school and active and role='teacher';
 select count(*) into staff_recorded from public.erp_staff_attendance where school_id=p_school and day=p_day;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.user_id,'name',p.display_name,'status',a.status)),'[]'::jsonb) into absent_staff from public.erp_staff_attendance a left join public.profiles p on p.id=a.user_id where a.school_id=p_school and a.day=p_day and a.status in ('absent','leave');
 select count(*) into pending from public.erp_leave_requests where school_id=p_school and status='pending';
 select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title) order by c.title, c.id), '[]'::jsonb)
 into unmarked from public.school_content c where c.kind='class' and c.school_id=p_school
 and not exists (select 1 from public.erp_attendance a where a.school_id=p_school and a.class_id=c.id and a.day=p_day);
 return jsonb_build_object('unmarked_classes',unmarked,'day',p_day,'total_students',nullif(total,0),'recorded_students',recorded,'attendance_percent',case when recorded=0 then null else round(present*100.0/recorded,1) end,'coverage_percent',case when total=0 then null else round(recorded*100.0/total,1) end,'absent_teachers',absent_staff,'staff_recorded',staff_recorded,'staff_total',nullif(staff_total,0),'pending_leave',pending);
end $$;
commit;
