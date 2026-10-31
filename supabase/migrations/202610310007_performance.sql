-- Performance review: covering foreign-key indexes and cached auth UID subplans.
-- No records are created or changed.
begin;
do $$ declare fk record;cols text;idx text;begin
 for fk in select c.conrelid,c.conname,c.conkey,n.nspname,t.relname from pg_constraint c join pg_class t on t.oid=c.conrelid join pg_namespace n on n.oid=t.relnamespace where c.contype='f' and n.nspname='public' and not exists(
   select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and i.indpred is null and
    (select array_agg(k.attnum order by k.ord) from unnest(i.indkey::smallint[]) with ordinality k(attnum,ord) where k.ord<=array_length(c.conkey,1))=c.conkey
 ) loop
  select string_agg(format('%I',a.attname),',' order by k.ord) into cols from unnest(fk.conkey) with ordinality k(attnum,ord) join pg_attribute a on a.attrelid=fk.conrelid and a.attnum=k.attnum;
  idx:=left(fk.relname,40)||'_fk_'||substr(md5(cols),1,10);
  execute format('create index if not exists %I on %I.%I (%s)',idx,fk.nspname,fk.relname,cols);
 end loop;
end $$;
do $$ declare p record;q text;w text;statement text;begin
 for p in select n.nspname,t.relname,pol.polname,pg_get_expr(pol.polqual,pol.polrelid) as qual,pg_get_expr(pol.polwithcheck,pol.polrelid) as checks from pg_policy pol join pg_class t on t.oid=pol.polrelid join pg_namespace n on n.oid=t.relnamespace where n.nspname='public' or (n.nspname='storage' and pol.polname in ('school_asset_upload','school_asset_read')) loop
  q:=replace(p.qual,'auth.uid()','(select auth.uid())');w:=replace(p.checks,'auth.uid()','(select auth.uid())');
  if q is distinct from p.qual or w is distinct from p.checks then
    statement:=format('alter policy %I on %I.%I',p.polname,p.nspname,p.relname);
    if q is not null then statement:=statement||' using ('||q||')';end if;
    if w is not null then statement:=statement||' with check ('||w||')';end if;
    execute statement;
  end if;
 end loop;
end $$;
commit;
