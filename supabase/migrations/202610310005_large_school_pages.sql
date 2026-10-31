-- Bounded APIs for schools with 500+ enrolled students. No seed data.
begin;
create function public.erp_grade_page(p_school uuid,p_assessment uuid,p_after uuid default null,p_limit integer default 100) returns jsonb language plpgsql security definer set search_path='' as $$
declare classroom uuid;
begin
 select class_id into classroom from public.erp_assessments where id=p_assessment and school_id=p_school;
 if classroom is null or not public.erp_can_class(p_school,classroom) then raise exception 'Assessment access denied' using errcode='42501';end if;
 return(select coalesce(jsonb_agg(to_jsonb(r) order by r.student_id),'[]'::jsonb) from(select * from public.erp_grades where school_id=p_school and assessment_id=p_assessment and (p_after is null or student_id>p_after) order by student_id limit greatest(1,least(coalesce(p_limit,100),100))) r);
end $$;
create function public.erp_conversations_page(p_school uuid,p_child uuid default null,p_after text default null,p_limit integer default 40) returns jsonb language plpgsql security definer set search_path='' as $$
declare stamp timestamptz;last_id uuid;staff boolean:=public.erp_has_role(p_school,array['teacher','principal','admin']);
begin
 if not public.erp_has_role(p_school,array['parent','student','teacher','principal','admin']) or (p_child is not null and not public.erp_can_student(p_school,p_child)) then raise exception 'School/child access denied' using errcode='42501';end if;
 if not staff and p_child is null then return '[]'::jsonb;end if;
 if p_after is not null then stamp:=split_part(p_after,'|',1)::timestamptz;last_id:=split_part(p_after,'|',2)::uuid;end if;
 return(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id desc),'[]'::jsonb) from(select c.*,s.name as student_name,p.display_name as contact_name,(select count(*) from public.erp_messages m left join public.erp_conversation_reads rd on rd.conversation_id=c.id and rd.user_id=auth.uid() where m.conversation_id=c.id and m.sender_id<>auth.uid() and m.created_at>coalesce(rd.read_at,'epoch'::timestamptz)) as unread_count from public.erp_conversations c join public.erp_students s on s.id=c.student_id left join public.profiles p on p.id=case when c.staff_id=auth.uid() then c.family_id else c.staff_id end where c.school_id=p_school and public.erp_can_conversation(p_school,c.id) and (staff or c.student_id=p_child) and (p_after is null or (c.created_at,c.id)<(stamp,last_id)) order by c.created_at desc,c.id desc limit greatest(1,least(coalesce(p_limit,40),100))) r);
end $$;
revoke all on function public.erp_grade_page(uuid,uuid,uuid,integer),public.erp_conversations_page(uuid,uuid,text,integer) from public,anon,authenticated;
grant execute on function public.erp_grade_page(uuid,uuid,uuid,integer),public.erp_conversations_page(uuid,uuid,text,integer) to authenticated;
commit;
