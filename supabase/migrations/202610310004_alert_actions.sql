begin;
alter function public.erp_alert_context(uuid) rename to erp_alert_context_v3;
create function public.erp_alert_context(p_event uuid) returns jsonb language sql security definer set search_path='' as $$
 select public.erp_alert_context_v3(p_event)||jsonb_build_object('can_approve',exists(select 1 from public.erp_notification_outbox e join public.erp_leave_requests l on l.id=e.entity_id and l.school_id=e.school_id join public.school_memberships m on m.school_id=e.school_id and m.user_id=e.user_id and m.active and m.role in ('teacher','principal','admin') where e.id=p_event and e.category='leave' and l.status='pending'));
$$;
revoke all on function public.erp_alert_context_v3(uuid),public.erp_alert_context(uuid) from public,anon,authenticated;
grant execute on function public.erp_alert_context_v3(uuid),public.erp_alert_context(uuid) to service_role;
-- The older workspace implementation is internal to the wrapper.
revoke execute on function public.erp_workspace_v2(uuid,uuid) from authenticated;
commit;
