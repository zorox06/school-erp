begin;

-- Only the database operator can bootstrap an owner. School admin is a separate legacy role.
create table public.erp_platform_owners(user_id uuid primary key references auth.users on delete cascade);
create sequence public.erp_school_codes start with 100001;
alter table public.schools add column school_code text not null unique
  default ('SCH-' || nextval('public.erp_school_codes')::text);

alter table public.erp_class_teachers add column homeroom boolean not null default false;
create unique index erp_one_homeroom_teacher on public.erp_class_teachers(school_id,class_id) where homeroom;
create table public.erp_enrollments(
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools,
  email text not null, role text not null check(role in ('principal','teacher','parent')),
  token_hash bytea not null, expires_at timestamptz not null, unique(school_id,email)
);
alter table public.erp_platform_owners enable row level security;
alter table public.erp_enrollments enable row level security;
revoke all on public.erp_platform_owners, public.erp_enrollments from public,anon,authenticated;
create function public.erp_is_owner() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.erp_platform_owners where user_id=auth.uid());
$$;
create or replace function public.erp_has_role(p_school uuid,p_roles text[]) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.school_memberships m where m.school_id=p_school and m.user_id=auth.uid() and m.active and m.role=any(p_roles))
 or ('admin'=any(p_roles) and public.erp_is_owner() and exists(select 1 from public.schools where id=p_school));
$$;
create policy school_owner_read on public.schools for select to authenticated using(public.erp_is_owner());
alter policy operations_self on public.erp_operations using (
 user_id=auth.uid() and public.erp_has_role(school_id,array['admin','principal','teacher','parent','student'])
);
create function public.erp_is_family(p_school uuid,p_student uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select (public.erp_has_role(p_school,array['parent']) and exists(select 1 from public.erp_guardians
    where school_id=p_school and student_id=p_student and user_id=auth.uid()))
 or (public.erp_has_role(p_school,array['student']) and exists(select 1 from public.erp_students
    where school_id=p_school and id=p_student and user_id=auth.uid()));
$$;
create or replace function public.erp_can_student(p_school uuid,p_student uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.erp_students s where s.school_id=p_school and s.id=p_student)
 and (public.erp_has_role(p_school,array['admin','principal']) or public.erp_is_family(p_school,p_student)
   or exists(select 1 from public.erp_class_students cs where cs.school_id=p_school and cs.student_id=p_student
     and public.erp_can_class(p_school,cs.class_id)));
$$;
create policy family_invoice_read on public.school_content for select to authenticated using (
 kind='invoice' and exists(select 1 from public.erp_students s where s.school_id=school_content.school_id
    and s.id::text=coalesce(school_content.data->>'student_id',school_content.data->>'child_id',school_content.data#>>'{data,child_id}')
    and public.erp_is_family(s.school_id,s.id))
);
alter policy roster_authorized on public.erp_class_students using (
 public.erp_can_class(school_id,class_id) or public.erp_is_family(school_id,student_id)
);
alter policy attendance_authorized on public.erp_attendance using (
 public.erp_can_class(school_id,class_id) or public.erp_is_family(school_id,student_id)
);
alter policy content_authorized_read on public.school_content using (
 public.erp_has_role(school_id,array['admin','principal']) or (
 public.erp_has_role(school_id,array['parent','student','teacher']) and
 case when kind='class' then public.erp_can_class(school_id,id) or exists(
   select 1 from public.erp_class_students cs where cs.school_id=school_content.school_id and cs.class_id=school_content.id
   and public.erp_is_family(cs.school_id,cs.student_id))
 when kind='invoice' and coalesce(data->>'student_id',data->>'child_id',data#>>'{data,child_id}') is not null then false
 else created_by=auth.uid() or visible_to @> array[auth.uid()] end)
);

create or replace function public.erp_attendance_delta(p_school uuid,p_cursor text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare records jsonb; cursor_value bigint := coalesce(nullif(p_cursor,''),'0')::bigint; next_cursor bigint;
begin
  if not public.erp_has_role(p_school,array['admin','principal','teacher','parent','student']) then raise exception 'School access denied' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_school::text,0));
  select coalesce(jsonb_agg(to_jsonb(r) order by r.revision),'[]'::jsonb), max(r.revision) into records,next_cursor from
    (select a.* from public.erp_attendance a where a.school_id=p_school and a.revision>cursor_value
      and (public.erp_can_class(p_school,a.class_id) or public.erp_is_family(p_school,a.student_id)) order by a.revision limit 100) r;
  return jsonb_build_object('records',records,'cursor',coalesce(next_cursor,cursor_value)::text,'has_more',jsonb_array_length(records)=100);
end;
$$;
create or replace function public.erp_workspace(p_school uuid,p_child uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;slots jsonb;
begin
 -- Student-specific workspace requests are for linked families and school leadership.
 if p_child is not null and not (public.erp_is_family(p_school,p_child) or public.erp_has_role(p_school,array['principal','admin'])) then
   raise insufficient_privilege;
 end if;
 result:=public.erp_workspace_v3(p_school,p_child);
 if public.erp_has_role(p_school,array['teacher','principal','admin']) then
  select coalesce(jsonb_agg(value),'[]'::jsonb) into slots from(
   select distinct on(value->>'id') value from(
    select value from jsonb_array_elements(result->'timetable')
    union all select jsonb_build_object('id',c.id,'title',c.title,'description',c.description,'date',c.date,'data',c.data) from public.school_content c where c.school_id=p_school and c.kind='timetable' and c.data->>'substitute_id'=auth.uid()::text) x
  ) y;
  result:=jsonb_set(result,array['timetable'],slots);
 end if;
 return result;
end $$;
create function public.erp_school_list() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('owner',public.erp_is_owner(),'schools',coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'code',s.school_code) order by s.name,s.school_code),'[]'::jsonb))
 from public.schools s where public.erp_is_owner() or exists(select 1 from public.school_memberships m where m.school_id=s.id and m.user_id=auth.uid() and m.active);
$$;
create function public.erp_create_school(p_name text) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.schools;
begin
 if not public.erp_is_owner() then raise insufficient_privilege; end if;
 if coalesce(length(trim(p_name)),0) not between 1 and 160 then raise exception 'Enter a school name'; end if;
 insert into public.schools(name) values(trim(p_name)) returning * into s;
 insert into public.erp_audit_events(school_id,actor,action,entity_id) values(s.id,auth.uid(),'school.create',s.id::text);
 return jsonb_build_object('id',s.id,'name',s.name,'code',s.school_code);
end $$;
create function public.erp_issue_enrollment(p_school uuid,p_email text,p_role text) returns text language plpgsql security definer set search_path='' as $$
declare token text:=gen_random_uuid()::text; addr text:=lower(trim(p_email));
begin
 if not public.erp_is_owner() then raise insufficient_privilege; end if;
 if p_role is null or p_role not in ('principal','teacher','parent') or addr is null or length(addr)>254 or addr !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'Invalid email or role'; end if;
 insert into public.erp_enrollments(school_id,email,role,token_hash,expires_at)
 values(p_school,addr,p_role,sha256(convert_to(token,'UTF8')),now()+interval '7 days')
 on conflict(school_id,email) do update set role=excluded.role,token_hash=excluded.token_hash,expires_at=excluded.expires_at;
 insert into public.erp_audit_events(school_id,actor,action,entity_id) values(p_school,auth.uid(),'access.invite',addr);
 return token;
end $$;
create function public.erp_accept_enrollment(p_code text,p_token text,p_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare inv public.erp_enrollments; addr text;
begin
 select lower(email) into addr from auth.users where id=auth.uid() and email_confirmed_at is not null for update;
 if addr is null then raise insufficient_privilege; end if;
 if coalesce(length(trim(p_name)),0) not between 1 and 160 then raise exception 'Enter your name'; end if;
 select i.* into inv from public.erp_enrollments i join public.schools s on s.id=i.school_id where s.school_code=upper(trim(p_code)) and i.email=addr and i.expires_at>now()
 and i.token_hash=sha256(convert_to(trim(p_token),'UTF8')) for update of i;
 if not found then raise insufficient_privilege; end if;
 if exists(select 1 from public.school_memberships where school_id=inv.school_id and user_id=auth.uid() and active and role<>inv.role) then raise exception 'Revoke the current role before changing roles'; end if;
 insert into public.profiles(id,display_name) values(auth.uid(),trim(p_name)) on conflict(id) do update set display_name=excluded.display_name;
 insert into public.school_memberships(school_id,user_id,role,active) values(inv.school_id,auth.uid(),inv.role,true)
 on conflict(school_id,user_id,role) do update set active=true;
 delete from public.erp_enrollments where id=inv.id;
 insert into public.erp_audit_events(school_id,actor,action,entity_id) values(inv.school_id,auth.uid(),'access.accept',auth.uid()::text);
 return inv.school_id;
end $$;
create function public.erp_school_access(p_school uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.erp_is_owner() then raise insufficient_privilege; end if;
 return jsonb_build_object('members',(select coalesce(jsonb_agg(to_jsonb(r) order by r.email),'[]'::jsonb) from
 (select m.id,m.user_id,m.role,m.active,u.email,p.display_name as name from public.school_memberships m join auth.users u on m.user_id=u.id left join public.profiles p on p.id=u.id where m.school_id=p_school) r),
 'invites',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'email',email,'role',role,'expires_at',expires_at) order by email),'[]'::jsonb) from public.erp_enrollments where school_id=p_school),
 'teachers',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.erp_class_teachers t where school_id=p_school),
 'guardians',(select coalesce(jsonb_agg(to_jsonb(g)),'[]'::jsonb) from public.erp_guardians g where school_id=p_school));
end $$;
create function public.erp_set_access(p_school uuid,p_id uuid,p_action text) returns void language plpgsql security definer set search_path='' as $$
declare m public.school_memberships;
begin
 if not public.erp_is_owner() then raise insufficient_privilege; end if;
 if p_action='cancel' then
   delete from public.erp_enrollments where id=p_id and school_id=p_school;
   if not found then raise exception 'Invitation no longer exists';end if;
 elsif p_action in ('grant','revoke') then
   perform 1 from auth.users where id=(select user_id from public.school_memberships where id=p_id and school_id=p_school) for update;
   select * into strict m from public.school_memberships where id=p_id and school_id=p_school for update;
   if p_action='grant' and exists(select 1 from public.school_memberships where school_id=p_school and user_id=m.user_id and active and id<>p_id) then raise exception 'Revoke the other active role first';end if;
   update public.school_memberships set active=(p_action='grant') where id=m.id;
   delete from public.erp_enrollments where school_id=p_school and email=(select lower(email) from auth.users where id=m.user_id);
   if p_action='revoke' then delete from public.erp_device_tokens where school_id=p_school and user_id=m.user_id;end if;
 else raise exception 'Invalid action';end if;
 insert into public.erp_audit_events(school_id,actor,action,entity_id) values(p_school,auth.uid(),'access.'||p_action,p_id::text);
end $$;

create function public.erp_set_assignment(p_school uuid,p_member uuid,p_target uuid,p_kind text) returns void language plpgsql security definer set search_path='' as $$
declare m public.school_memberships;
begin
 if not public.erp_is_owner() then raise insufficient_privilege;end if;
 select * into strict m from public.school_memberships where school_id=p_school and id=p_member and active for update;
 if m.role='teacher' and p_kind in ('teaching','homeroom','remove_teacher') and exists(select 1 from public.school_content where id=p_target and school_id=p_school and kind='class') then
   if p_kind='homeroom' then
     update public.erp_class_teachers t set homeroom=false where t.school_id=p_school and t.class_id=p_target and t.homeroom
       and not exists(select 1 from public.school_memberships a where a.school_id=t.school_id and a.user_id=t.user_id and a.active and a.role='teacher');
   end if;
   if p_kind='remove_teacher' then delete from public.erp_class_teachers where school_id=p_school and class_id=p_target and user_id=m.user_id;
   else insert into public.erp_class_teachers(school_id,class_id,user_id,homeroom) values(p_school,p_target,m.user_id,p_kind='homeroom') on conflict(school_id,class_id,user_id) do update set homeroom=excluded.homeroom;end if;
 elsif m.role='parent' and p_kind in ('guardian','remove_guardian') and exists(select 1 from public.erp_students where id=p_target and school_id=p_school) then
   if p_kind='remove_guardian' then delete from public.erp_guardians where school_id=p_school and student_id=p_target and user_id=m.user_id;
   else insert into public.erp_guardians values(p_school,p_target,m.user_id) on conflict do nothing;end if;
 else raise exception 'Choose a valid assignment in this school';end if;
 insert into public.erp_audit_events(school_id,actor,action,entity_id,after_value) values(p_school,auth.uid(),'assignment.'||p_kind,p_target::text,jsonb_build_object('member',p_member));
end $$;
create function public.erp_add_roster_record(p_school uuid,p_name text,p_class uuid default null,p_roll text default null) returns uuid language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
 if not public.erp_has_role(p_school,array['admin','principal']) then raise insufficient_privilege;end if;
 if coalesce(length(trim(p_name)),0) not between 1 and 160 then raise exception 'Enter a name';end if;
 if p_class is null then insert into public.school_content(school_id,kind,title,created_by) values(p_school,'class',trim(p_name),auth.uid()) returning id into target;
 else
   if not public.erp_can_class(p_school,p_class) then raise insufficient_privilege;end if;
   insert into public.erp_students(school_id,name,roll) values(p_school,trim(p_name),nullif(trim(p_roll),'')) returning id into target;
   insert into public.erp_class_students values(p_school,p_class,target);
 end if;
 insert into public.erp_audit_events(school_id,actor,action,entity_id) values(p_school,auth.uid(),case when p_class is null then 'class.create' else 'student.create' end,target::text);
 return target;
end $$;
create function public.erp_student_directory(p_school uuid,p_class uuid default null,p_search text default '',p_after uuid default null) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(r) order by r.id),'[]'::jsonb) from (
 select s.id,s.name,s.roll from public.erp_students s where s.school_id=p_school and public.erp_can_student(p_school,s.id)
 and (p_class is null or (public.erp_can_class(p_school,p_class) and exists(select 1 from public.erp_class_students cs where cs.school_id=p_school and cs.class_id=p_class and cs.student_id=s.id)))
 and (p_after is null or s.id>p_after) and (position(lower(coalesce(p_search,'')) in lower(s.name))>0 or s.roll=p_search) order by s.id limit 100) r;
$$;
create function public.erp_student_details(p_school uuid,p_student uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; full_access boolean;
begin
 if not exists(select 1 from public.erp_students where id=p_student and school_id=p_school) or not public.erp_can_student(p_school,p_student) then raise insufficient_privilege;end if;
 full_access:=public.erp_has_role(p_school,array['admin','principal']) or public.erp_is_family(p_school,p_student)
 or exists(select 1 from public.erp_class_students cs join public.erp_class_teachers t using(school_id,class_id)
 where cs.school_id=p_school and cs.student_id=p_student and t.user_id=auth.uid() and t.homeroom and public.erp_has_role(p_school,array['teacher']));
 select jsonb_build_object('name',s.name,'roll',s.roll,'full_access',full_access,'classes',(select coalesce(jsonb_agg(c.title order by c.title),'[]'::jsonb) from public.erp_class_students cs join public.school_content c on c.school_id=cs.school_id and c.id=cs.class_id where cs.school_id=p_school and cs.student_id=s.id and (full_access or public.erp_can_class(p_school,cs.class_id)))) into result from public.erp_students s where s.school_id=p_school and s.id=p_student;
 if full_access then result:=result||jsonb_build_object(
 'guardians',(select coalesce(jsonb_agg(jsonb_build_object('name',p.display_name,'email',u.email)),'[]'::jsonb) from public.erp_guardians g join auth.users u on u.id=g.user_id left join public.profiles p on p.id=g.user_id where g.school_id=p_school and g.student_id=p_student),
 'fees',(select coalesce(jsonb_agg(c.data||jsonb_build_object('id',c.id,'title',c.title,'status',c.status)),'[]'::jsonb) from public.school_content c where c.school_id=p_school and c.kind='invoice' and coalesce(c.data->>'student_id',c.data->>'child_id',c.data#>>'{data,child_id}')=p_student::text),
 'attendance',(select count(*) from public.erp_attendance where school_id=p_school and student_id=p_student),
 'attendance_history',(select coalesce(jsonb_agg(to_jsonb(r) order by r.day desc),'[]'::jsonb) from
   (select day,status,reason from public.erp_attendance where school_id=p_school and student_id=p_student order by day desc limit 30) r),
 'leaves',(select coalesce(jsonb_agg(to_jsonb(r) order by r.starts_on desc),'[]'::jsonb) from
   (select id,starts_on,ends_on,status from public.erp_leave_requests where school_id=p_school and student_id=p_student order by starts_on desc,id limit 30) r),
 'grades',(select coalesce(jsonb_agg(jsonb_build_object('title',a.title,'subject',a.subject,'score',g.score,'maximum',a.max_score) order by a.exam_at desc),'[]'::jsonb) from public.erp_grades g join public.erp_assessments a on a.id=g.assessment_id where g.school_id=p_school and g.student_id=p_student));
 end if;return result;
end $$;
create function public.erp_class_team(p_school uuid,p_class uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',t.user_id,'name',coalesce(nullif(p.display_name,''),u.email),
   'homeroom',t.homeroom) order by t.homeroom desc,p.display_name,u.id),'[]'::jsonb)
 from public.erp_class_teachers t join auth.users u on u.id=t.user_id left join public.profiles p on p.id=t.user_id
 where t.school_id=p_school and t.class_id=p_class
 and exists(select 1 from public.school_memberships m where m.school_id=t.school_id and m.user_id=t.user_id and m.active and m.role='teacher')
 and (public.erp_has_role(p_school,array['admin','principal']) or
   (public.erp_has_role(p_school,array['teacher']) and exists(select 1 from public.erp_class_teachers own
    where own.school_id=p_school and own.class_id=p_class and own.user_id=auth.uid() and own.homeroom)));
$$;
create function public.erp_school_context(p_school uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare m public.school_memberships%rowtype; result jsonb; pair text[]; records jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into m from public.school_memberships where school_id=p_school and user_id=auth.uid() and active
    order by case role when 'admin' then 0 when 'principal' then 1 when 'teacher' then 2 when 'parent' then 3 else 4 end,id limit 1;
  if public.erp_is_owner() and exists(select 1 from public.schools where id=p_school) then m.school_id:=p_school; m.role:='admin'; end if;
  if m.school_id is null then raise insufficient_privilege; end if;
  result:=jsonb_build_object('school_code',(select school_code from public.schools where id=p_school),'platform_owner',public.erp_is_owner(),'school_id',m.school_id,'school_name',(select name from public.schools where id=m.school_id),
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
  if m.role in ('principal','teacher','admin') then
    select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'title',c.title,'description',c.description,'teachers',public.erp_class_team(p_school,c.id),'homeroom',exists(select 1 from public.erp_class_teachers t where t.school_id=p_school and t.user_id=auth.uid() and t.class_id=c.id and t.homeroom)) order by c.title),'[]'::jsonb)
    into records from public.school_content c where c.school_id=p_school and c.kind='class' and public.erp_can_class(p_school,c.id);
    result:=jsonb_set(result,array['classes'],records);
  end if;
  return result;
end;
$$;

-- Keep the installed mobile client on its original default-school contract.
-- The web entry also returns the list of schools available to this identity.
create function public.erp_web_entry() returns jsonb language sql stable security invoker set search_path='' as $$
 select public.erp_school_list();
$$;
do $grants$ declare f regprocedure;
begin
 for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in (
 'erp_is_owner','erp_is_family','erp_class_team','erp_web_entry','erp_school_context','erp_school_list','erp_create_school','erp_issue_enrollment','erp_accept_enrollment','erp_school_access','erp_set_access','erp_set_assignment','erp_add_roster_record','erp_student_directory','erp_student_details')
 loop execute format('revoke all on function %s from public,anon,authenticated',f); execute format('grant execute on function %s to authenticated',f);end loop;
end $grants$;
commit;
