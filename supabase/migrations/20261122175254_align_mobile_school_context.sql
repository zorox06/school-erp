create or replace function public.mobile_context() returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare
  account_id uuid := auth.uid();
  selected_school uuid;
begin
  if account_id is null then
    raise insufficient_privilege using message = 'Authentication required';
  end if;

  -- Keep the default school for existing mobile members.
  select m.school_id into selected_school
  from public.school_memberships m
  where m.user_id = account_id and m.active
  order by case m.role
    when 'admin' then 0 when 'principal' then 1 when 'teacher' then 2
    when 'parent' then 3 else 4
  end, m.id
  limit 1;

  if selected_school is null and public.erp_is_owner() then
    select s.id into selected_school
    from public.schools s
    order by s.name, s.school_code
    limit 1;
  end if;

  if selected_school is not null then
    return public.erp_school_context(selected_school);
  end if;

  return jsonb_build_object(
    'school_id', null, 'school_name', null, 'role', null,
    'display_name', (select p.display_name from public.profiles p where p.id = account_id),
    'children', '[]'::jsonb, 'classes', '[]'::jsonb, 'homework', '[]'::jsonb,
    'worksheets', '[]'::jsonb, 'timetable', '[]'::jsonb, 'attendance', '[]'::jsonb,
    'news', '[]'::jsonb, 'events', '[]'::jsonb, 'conversations', '[]'::jsonb,
    'invoices', '[]'::jsonb, 'notifications', '[]'::jsonb
  );
end;
$$;
