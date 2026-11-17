-- =====================================================================
-- Zenvique System — 07_ai_morning_brief.sql
-- AI Morning Brief on the Manager Dashboard:
--  * saves brief, manager name, outlet, date & time, filters used, "I have checked this"
--  * managers see only their outlet's briefs; owner sees all
--  * briefs are read-only after saving (only the owner can edit; edits are logged)
--  * saving and editing are written to the History log
-- Paste into Supabase > SQL Editor and click Run. Safe to run more than once.
-- =====================================================================

-- 1. New columns (scope = outlet)
alter table public.ai_briefs
  add column if not exists created_by_name text,
  add column if not exists filters         jsonb,
  add column if not exists updated_at      timestamptz,
  add column if not exists updated_by      uuid references public.profiles(id);

-- 2. Who saved it and when can't be faked; after saving only the brief text can change
create or replace function public.ai_briefs_before() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.created_at := now();
    new.created_by_name := coalesce(
      (select coalesce(p.full_name, p.email) from public.profiles p where p.id = new.created_by),
      new.created_by_name);
    new.updated_at := null; new.updated_by := null;
    if public.my_role() = 'manager' and new.scope is distinct from public.my_outlet() then
      raise exception 'You can only save briefs for your own outlet.';
    end if;
    return new;
  end if;
  -- UPDATE (owner only, by policy): keep the original facts
  new.id := old.id; new.created_by := old.created_by; new.created_at := old.created_at;
  new.created_by_name := old.created_by_name; new.scope := old.scope; new.period := old.period;
  new.prompt := old.prompt; new.filters := old.filters; new.checked := old.checked;
  new.updated_at := now(); new.updated_by := auth.uid();
  return new;
end $$;

drop trigger if exists ai_briefs_before on public.ai_briefs;
create trigger ai_briefs_before before insert or update on public.ai_briefs
  for each row execute function public.ai_briefs_before();

-- 3. History: saving is logged by the existing create trigger; log edits too
create or replace function public.ai_briefs_after_update() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.brief is distinct from old.brief then
    perform public.write_log('edit', 'ai_briefs', new.id::text, new.scope,
      jsonb_build_object('before', jsonb_build_object('brief', old.brief),
                         'after',  jsonb_build_object('brief', new.brief)));
  end if;
  return new;
end $$;

drop trigger if exists ai_briefs_log_update on public.ai_briefs;
create trigger ai_briefs_log_update after update on public.ai_briefs
  for each row execute function public.ai_briefs_after_update();

-- 4. Who can see / save / edit / delete
drop policy if exists briefs_select on public.ai_briefs;
create policy briefs_select on public.ai_briefs for select to authenticated
  using (public.my_role() = 'owner'
         or (public.my_role() = 'manager' and scope = public.my_outlet()));

drop policy if exists briefs_insert on public.ai_briefs;
create policy briefs_insert on public.ai_briefs for insert to authenticated
  with check (checked
              and (public.my_role() = 'owner'
                   or (public.my_role() = 'manager' and scope = public.my_outlet())));

drop policy if exists briefs_update on public.ai_briefs;
create policy briefs_update on public.ai_briefs for update to authenticated
  using (public.my_role() = 'owner') with check (public.my_role() = 'owner');

drop policy if exists briefs_delete on public.ai_briefs;
create policy briefs_delete on public.ai_briefs for delete to authenticated
  using (public.my_role() = 'owner');

grant select, insert, update, delete on public.ai_briefs to authenticated;

-- Done. You should see "Success. No rows returned".
