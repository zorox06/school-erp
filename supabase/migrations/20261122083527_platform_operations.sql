begin;

create function public.erp_platform_overview() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null or not public.erp_is_owner() then raise insufficient_privilege; end if;

  with membership as (
    select m.school_id,
      count(distinct m.user_id) filter (where m.active) as active_users,
      count(*) filter (where not m.active) as revoked_memberships,
      count(*) filter (where m.active and m.role = 'principal') as principals,
      count(*) filter (where m.active and m.role = 'teacher' and not exists (
        select 1 from public.erp_class_teachers t
        where t.school_id = m.school_id and t.user_id = m.user_id
      )) as unassigned_teachers,
      count(*) filter (where m.active and m.role = 'parent' and not exists (
        select 1 from public.erp_guardians g
        where g.school_id = m.school_id and g.user_id = m.user_id
      )) as unlinked_families
    from public.school_memberships m group by m.school_id
  ), invitations as (
    select school_id, count(*) filter (where expires_at > now()) as pending,
      count(*) filter (where expires_at <= now()) as expired
    from public.erp_enrollments group by school_id
  ), students as (
    select school_id, count(*) as total from public.erp_students group by school_id
  ), delivery as (
    select school_id, count(*) as outstanding,
      count(*) filter (where attempts < 10 and next_attempt <= now()
        and created_at < now() - interval '15 minutes'
        and (lease_until is null or lease_until <= now())) as overdue,
      count(*) filter (where attempts < 10 and last_error = 'delivery_retry') as retrying,
      count(*) filter (where attempts >= 10) as exhausted
    from public.erp_notification_outbox where delivered_at is null group by school_id
  ), schools as (
    select s.id, s.name, s.school_code as code,
      coalesce(m.active_users, 0) as active_users,
      coalesce(m.revoked_memberships, 0) as revoked_memberships,
      coalesce(m.principals, 0) as principals,
      coalesce(m.unassigned_teachers, 0) as unassigned_teachers,
      coalesce(m.unlinked_families, 0) as unlinked_families,
      coalesce(i.pending, 0) as pending_invites,
      coalesce(i.expired, 0) as expired_invites,
      coalesce(st.total, 0) as students,
      coalesce(d.overdue, 0) as overdue_notifications,
      coalesce(d.retrying, 0) as retrying_notifications,
      coalesce(d.exhausted, 0) as exhausted_notifications
    from public.schools s
    left join membership m on m.school_id = s.id
    left join invitations i on i.school_id = s.id
    left join students st on st.school_id = s.id
    left join delivery d on d.school_id = s.id
  )
  select jsonb_build_object(
    'checked_at', now(),
    'schools', (select coalesce(jsonb_agg(to_jsonb(s) order by s.name, s.code), '[]'::jsonb) from schools s),
    'accounts', (select jsonb_build_object('total', count(*),
      'unverified', count(*) filter (where email_confirmed_at is null and email is not null),
      'signed_in_24h', count(*) filter (where last_sign_in_at >= now() - interval '24 hours')) from auth.users),
    'active_members', (select count(distinct user_id) from public.school_memberships where active),
    'owner_accounts', (select count(*) from public.erp_platform_owners),
    'students', (select count(*) from public.erp_students),
    'pending_invites', (select coalesce(sum(pending), 0) from invitations),
    'roles', (select coalesce(jsonb_object_agg(role, total), '{}'::jsonb) from (
      select role, count(distinct user_id) as total from public.school_memberships where active group by role
    ) r),
    'notifications', (select jsonb_build_object(
      'outstanding', coalesce(sum(outstanding), 0), 'overdue', coalesce(sum(overdue), 0),
      'retrying', coalesce(sum(retrying), 0), 'exhausted', coalesce(sum(exhausted), 0)
    ) from delivery),
    'registered_devices', (select count(*) from public.erp_device_tokens),
    'recent_activity', (select coalesce(jsonb_agg(to_jsonb(a) order by a.at desc, a.id desc), '[]'::jsonb)
      from (select e.id, e.action, e.at, s.name, s.school_code as code
        from public.erp_audit_events e join public.schools s on s.id = e.school_id
        where e.action in ('school.create', 'access.invite', 'access.accept', 'access.grant', 'access.revoke', 'access.cancel')
        order by e.at desc, e.id desc limit 12) a)
  ) into result;
  return result;
end;
$$;

create function public.erp_platform_school(p_school uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null or not public.erp_is_owner() then raise insufficient_privilege; end if;
  select jsonb_build_object('school_id', s.id, 'school_name', s.name, 'school_code', s.school_code,
    'role', 'admin', 'classes', (
      select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title) order by c.title, c.id), '[]'::jsonb)
      from public.school_content c where c.school_id = s.id and c.kind = 'class'
    )) into result from public.schools s where s.id = p_school;
  if result is null then raise insufficient_privilege; end if;
  return result;
end;
$$;

revoke execute on function public.erp_platform_overview(), public.erp_platform_school(uuid) from public, anon, authenticated;
grant execute on function public.erp_platform_overview(), public.erp_platform_school(uuid) to authenticated;

commit;
